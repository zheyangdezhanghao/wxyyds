// Intel 269077 — 聊天内灰字撤回提示（指针对齐 SovietExtension 图2）
#import "WXRevokeInChat.h"
#import "WXCommon.h"

#import <mach/mach.h>
#import <mach-o/dyld.h>

#include <string>
#include <cstring>

#pragma mark - Profile (offsets/hook_269077.json)

typedef struct {
    size_t messageWrapSize;
    size_t remoteUserOrSessionOffset;
    size_t selfUserOffset;
    size_t createTimeMsOffset;
    size_t createTimeSecOffset;
    size_t contentOffset;
} WXMessageWrapLayout;

typedef struct {
    const char *buildVersion;
    uintptr_t hookPointerVA;
    uintptr_t revokeHandlerVA;
    uintptr_t rawMessageTemplateVA;
    uintptr_t messageWrapFromRawVA;
    uintptr_t messageWrapDestructVA;
    uintptr_t insertPaySysMsgToSessionVA;
    WXMessageWrapLayout layout;
} WXRevokeProfile;

static const WXRevokeProfile kProfile269077 = {
    .buildVersion = "269077",
    .hookPointerVA = 0x94D5750,
    .revokeHandlerVA = 0x4F4D4C0,
    .rawMessageTemplateVA = 0x7F62B30,
    .messageWrapFromRawVA = 0x4DF60F0,
    .messageWrapDestructVA = 0x5178C90,
    .insertPaySysMsgToSessionVA = 0x3814750,
    .layout = {
        .messageWrapSize = 616,
        .remoteUserOrSessionOffset = 24,
        .selfUserOffset = 48,
        .createTimeMsOffset = 256,
        .createTimeSecOffset = 276,
        .contentOffset = 328,
    },
};

#pragma mark - WeChat internals

typedef void (*WXMessageWrapFromRawFunc)(void *message, int64_t rawMessage);
typedef void (*WXMessageWrapDestructFunc)(int64_t message);
typedef int64_t (*WXInsertPaySysMsgToSessionFunc)(int64_t a1,
                                                  const std::string *session,
                                                  const std::string *content);

static uintptr_t g_dylibSlide = 0;
static BOOL g_hookInstalled = NO;
static const WXRevokeProfile *g_profile = NULL;

static uintptr_t WXRuntimePtr(uintptr_t va) {
    return g_dylibSlide + va;
}

#pragma mark - Helpers

static std::string WXStdStringFromNSString(NSString *text) {
    if (!text) return std::string();
    const char *utf8 = [text UTF8String];
    return utf8 ? std::string(utf8) : std::string();
}

static NSString *WXNSStringFromStdString(const std::string *value) {
    if (!value) return @"";
    const char *cString = NULL;
    try {
        cString = value->c_str();
    } catch (...) {
        return @"";
    }
    return cString ? ([NSString stringWithUTF8String:cString] ?: @"") : @"";
}

static BOOL WXSafeRead(uintptr_t address, void *buffer, size_t size) {
    if (address == 0 || !buffer || size == 0) return NO;
    vm_size_t outSize = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         (vm_address_t)address,
                                         (vm_size_t)size,
                                         (vm_address_t)buffer,
                                         &outSize);
    return kr == KERN_SUCCESS && outSize == size;
}

static std::string *WXWrapStringField(void *rawWrap, size_t offset) {
    return rawWrap ? (std::string *)((uint8_t *)rawWrap + offset) : NULL;
}

static uint32_t WXWrapUInt32(void *rawWrap, size_t offset) {
    return rawWrap ? *(uint32_t *)((uint8_t *)rawWrap + offset) : 0;
}

static uint64_t WXWrapUInt64(void *rawWrap, size_t offset) {
    return rawWrap ? *(uint64_t *)((uint8_t *)rawWrap + offset) : 0;
}

static NSString *WXFormatTimestamp(uint32_t createTimeSec, uint64_t createTimeMs) {
    NSTimeInterval ts = 0;
    if (createTimeSec > 0) {
        ts = (NSTimeInterval)createTimeSec;
    } else if (createTimeMs > 0) {
        ts = (NSTimeInterval)(createTimeMs / 1000);
    } else {
        ts = [[NSDate date] timeIntervalSince1970];
    }
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    fmt.timeZone = [NSTimeZone localTimeZone];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]] ?: @"";
}

static NSString *WXExtractXMLTag(NSString *xml, NSString *tag) {
    if (xml.length == 0 || tag.length == 0) return @"";
    NSString *openTag = [NSString stringWithFormat:@"<%@>", tag];
    NSString *closeTag = [NSString stringWithFormat:@"</%@>", tag];
    NSRange openRange = [xml rangeOfString:openTag options:NSCaseInsensitiveSearch];
    if (openRange.location == NSNotFound) return @"";
    NSUInteger valueStart = NSMaxRange(openRange);
    if (valueStart >= xml.length) return @"";
    NSRange searchRange = NSMakeRange(valueStart, xml.length - valueStart);
    NSRange closeRange = [xml rangeOfString:closeTag options:NSCaseInsensitiveSearch range:searchRange];
    if (closeRange.location == NSNotFound || closeRange.location < valueStart) return @"";
    NSString *value = [xml substringWithRange:NSMakeRange(valueStart, closeRange.location - valueStart)] ?: @"";
    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

static NSString *WXRevokerFromXMLPrefix(NSString *xml) {
    if (xml.length == 0) return @"";
    NSRange sysmsgRange = [xml rangeOfString:@"<sysmsg" options:NSCaseInsensitiveSearch];
    if (sysmsgRange.location == NSNotFound || sysmsgRange.location == 0) return @"";
    NSString *prefix = [[xml substringToIndex:sysmsgRange.location]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([prefix hasSuffix:@":"]) {
        prefix = [prefix substringToIndex:prefix.length - 1];
    }
    return prefix.length > 0 ? prefix : @"";
}

static NSString *WXDisplayNameFromReplaceMsg(NSString *replaceMsg) {
    if (replaceMsg.length == 0) return @"";
    NSRange firstQuote = [replaceMsg rangeOfString:@"\""];
    if (firstQuote.location != NSNotFound) {
        NSRange searchRange = NSMakeRange(NSMaxRange(firstQuote), replaceMsg.length - NSMaxRange(firstQuote));
        NSRange secondQuote = [replaceMsg rangeOfString:@"\"" options:0 range:searchRange];
        if (secondQuote.location != NSNotFound && secondQuote.location > NSMaxRange(firstQuote)) {
            NSString *name = [replaceMsg substringWithRange:NSMakeRange(NSMaxRange(firstQuote),
                                                                      secondQuote.location - NSMaxRange(firstQuote))];
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (name.length > 0) return name;
        }
    }
    NSString *name = [replaceMsg copy];
    for (NSString *suffix in @[@"撤回了一条消息", @"撤回了消息", @"recalled a message"]) {
        NSRange range = [name rangeOfString:suffix options:NSCaseInsensitiveSearch];
        if (range.location != NSNotFound) {
            name = [name substringToIndex:range.location];
            break;
        }
    }
    return [[name stringByReplacingOccurrencesOfString:@"\"" withString:@""]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
}

static NSString *WXFindRevokeXML(void *rawWrap, size_t wrapSize) {
    if (!rawWrap || wrapSize < 24) return @"";
    const size_t preferredOffsets[] = {304, 328, 352, 376, 400, 424, 448, 280, 248, 224, 200};
    for (size_t i = 0; i < sizeof(preferredOffsets) / sizeof(preferredOffsets[0]); i++) {
        size_t offset = preferredOffsets[i];
        if (offset + 24 > wrapSize) continue;
        NSString *value = WXNSStringFromStdString(WXWrapStringField(rawWrap, offset));
        NSString *lower = value.lowercaseString;
        if ([lower containsString:@"<sysmsg"] && [lower containsString:@"revokemsg"]) {
            return value ?: @"";
        }
    }
    for (size_t offset = 0; offset + 24 <= wrapSize; offset += 8) {
        NSString *value = WXNSStringFromStdString(WXWrapStringField(rawWrap, offset));
        NSString *lower = value.lowercaseString;
        if ([lower containsString:@"<sysmsg"] && [lower containsString:@"revokemsg"]) {
            return value ?: @"";
        }
    }
    return @"";
}

static NSString *WXMessageTypeName(uint32_t type) {
    switch (type) {
        case 1: return @"[文本消息]";
        case 3: return @"[图片消息]";
        case 34: return @"[语音消息]";
        case 43: return @"[视频消息]";
        case 47: return @"[表情包]";
        case 48: return @"[位置消息]";
        case 49: return @"[卡片/文件/链接消息]";
        default:
            return type > 0 ? [NSString stringWithFormat:@"[%u]", type] : @"";
    }
}

static uint32_t WXGuessMessageType(void *rawWrap, size_t wrapSize) {
    static const size_t offsets[] = {216, 220, 208, 212, 200, 204, 224, 228, 192, 196};
    for (size_t i = 0; i < sizeof(offsets) / sizeof(offsets[0]); i++) {
        size_t off = offsets[i];
        if (off + 4 > wrapSize) continue;
        uint32_t v = WXWrapUInt32(rawWrap, off);
        if (v == 1 || v == 3 || v == 34 || v == 43 || v == 47 || v == 48 || v == 49) {
            return v;
        }
    }
    return 0;
}

static NSString *WXCleanTextContent(NSString *rawContent) {
    if (rawContent.length == 0) return @"";
    NSString *text = [rawContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"";
    NSRange colonNewline = [text rangeOfString:@":\n"];
    if (colonNewline.location != NSNotFound && colonNewline.location > 0) {
        NSString *body = [text substringFromIndex:NSMaxRange(colonNewline)] ?: @"";
        body = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (body.length > 0) return body;
    }
    return text;
}

static BOOL WXRevokeHandlerIsStaticPatched(void) {
    if (!g_profile || g_dylibSlide == 0) return NO;
    uint8_t bytes[6] = {0};
    if (!WXSafeRead(WXRuntimePtr(g_profile->revokeHandlerVA), bytes, sizeof(bytes))) {
        return NO;
    }
    return bytes[0] == 0xB8 && bytes[1] == 0x01 && bytes[5] == 0xC3;
}

static BOOL WXWritePointer(uintptr_t address, uintptr_t value) {
    if (address == 0 || value == 0) return NO;
    uintptr_t *target = (uintptr_t *)address;
    uintptr_t current = *target;
    if (current == value) return YES;
    if (current != 0 && current != value) {
        WXLog(@"RevokeInChat: pointer slot already set (0x%lx), skip", (unsigned long)current);
        return NO;
    }
    vm_size_t pageSize = (vm_size_t)getpagesize();
    vm_address_t pageStart = (vm_address_t)(address & ~((uintptr_t)pageSize - 1));
    kern_return_t kr = vm_protect(mach_task_self(),
                                  pageStart,
                                  pageSize,
                                  false,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        WXLog(@"RevokeInChat: vm_protect failed kr=%d", kr);
        return NO;
    }
    __atomic_store_n(target, value, __ATOMIC_SEQ_CST);
    return YES;
}

#pragma mark - Notice (align Soviet 图2)

static NSString *WXBuildNoticeText(void *rawWrap,
                                   size_t wrapSize,
                                   NSString *remoteUserOrSession,
                                   NSString *selfUser,
                                   NSString *messageTimeText,
                                   NSString *revokerWxid,
                                   NSString *replaceMsg) {
    uint32_t msgType = WXGuessMessageType(rawWrap, wrapSize);
    NSString *typeLine = WXMessageTypeName(msgType);
    NSString *displayName = WXDisplayNameFromReplaceMsg(replaceMsg);

    NSMutableString *text = [NSMutableString string];
    [text appendString:@"⚠️ wxyyds 已拦截撤回消息 ⚠️\n"];
    if (typeLine.length > 0) {
        [text appendFormat:@"%@\n", typeLine];
    }

    if (msgType == 1) {
        NSString *rawContent = WXNSStringFromStdString(WXWrapStringField(rawWrap, g_profile->layout.contentOffset));
        NSString *clean = WXCleanTextContent(rawContent);
        if (clean.length > 0) {
            if (clean.length > 1200) {
                clean = [[clean substringToIndex:1200] stringByAppendingString:@"…"];
            }
            [text appendFormat:@"内容：%@\n", clean];
        }
    }

    if (displayName.length > 0 && revokerWxid.length > 0) {
        [text appendFormat:@"%@（%@）\n", displayName, revokerWxid];
    } else if (displayName.length > 0) {
        [text appendFormat:@"%@\n", displayName];
    } else if (revokerWxid.length > 0) {
        [text appendFormat:@"%@\n", revokerWxid];
    } else {
        [text appendFormat:@"撤回方/会话：%@\n", remoteUserOrSession ?: @""];
    }

    if (messageTimeText.length > 0) {
        [text appendString:messageTimeText];
    }
    (void)selfUser;
    return text;
}

static BOOL WXInsertLocalNotice(int64_t rawRevokeMessage) {
    if (!g_profile || rawRevokeMessage == 0 || g_dylibSlide == 0) return NO;

    WXMessageWrapFromRawFunc fromRaw =
        (WXMessageWrapFromRawFunc)WXRuntimePtr(g_profile->messageWrapFromRawVA);
    WXMessageWrapDestructFunc destruct =
        (WXMessageWrapDestructFunc)WXRuntimePtr(g_profile->messageWrapDestructVA);
    WXInsertPaySysMsgToSessionFunc insert =
        (WXInsertPaySysMsgToSessionFunc)WXRuntimePtr(g_profile->insertPaySysMsgToSessionVA);
    void *rawTemplate = (void *)WXRuntimePtr(g_profile->rawMessageTemplateVA);

    if (!fromRaw || !destruct || !insert || !rawTemplate) {
        WXLog(@"RevokeInChat: internal function pointer missing");
        return NO;
    }

    const size_t wrapSize = g_profile->layout.messageWrapSize;
    alignas(16) uint8_t rawWrap[616];
    if (wrapSize > sizeof(rawWrap)) return NO;
    memset(rawWrap, 0, sizeof(rawWrap));
    memcpy(rawWrap, rawTemplate, wrapSize);

    fromRaw(rawWrap, rawRevokeMessage);

    BOOL ok = NO;
    try {
        std::string *sessionField = WXWrapStringField(rawWrap, g_profile->layout.remoteUserOrSessionOffset);
        std::string *selfField = WXWrapStringField(rawWrap, g_profile->layout.selfUserOffset);
        std::string *session = sessionField;
        if (!session || session->empty()) {
            session = selfField;
        }
        if (!session || session->empty()) {
            WXLog(@"RevokeInChat: session empty");
            destruct((int64_t)rawWrap);
            return NO;
        }

        NSString *remoteText = WXNSStringFromStdString(sessionField);
        NSString *selfText = WXNSStringFromStdString(selfField);
        uint32_t sec = WXWrapUInt32(rawWrap, g_profile->layout.createTimeSecOffset);
        uint64_t ms = WXWrapUInt64(rawWrap, g_profile->layout.createTimeMsOffset);
        NSString *timeText = WXFormatTimestamp(sec, ms);

        NSString *revokerWxid = WXNSStringFromStdString(WXWrapStringField(rawWrap, 72));
        NSString *revokeXML = WXFindRevokeXML(rawWrap, wrapSize);
        if (revokerWxid.length == 0) {
            revokerWxid = WXRevokerFromXMLPrefix(revokeXML);
        }
        NSString *replaceMsg = WXExtractXMLTag(revokeXML, @"replacemsg");

        NSString *noticeText = WXBuildNoticeText(rawWrap,
                                                 wrapSize,
                                                 remoteText,
                                                 selfText,
                                                 timeText,
                                                 revokerWxid,
                                                 replaceMsg);
        if (noticeText.length == 0) {
            noticeText = [NSString stringWithFormat:@"⚠️ wxyyds 已拦截撤回消息 ⚠️\n会话：%@\n%@",
                          remoteText ?: @"", timeText ?: @""];
        }

        std::string content = WXStdStringFromNSString(noticeText);
        WXLog(@"RevokeInChat: insert session=%s", session->c_str());
        int64_t result = insert(0, session, &content);
        WXLog(@"RevokeInChat: insertPaySysMsgToSession result=0x%llx", (unsigned long long)result);
        ok = YES;
    } catch (...) {
        WXLog(@"RevokeInChat: exception during insert");
        ok = NO;
    }

    destruct((int64_t)rawWrap);
    return ok;
}

#pragma mark - Hook

static int64_t WXHandleSysMsgRevokeHook(int64_t a1, int64_t a2) {
    WXLog(@"RevokeInChat: intercepted revoke a1=0x%llx a2=0x%llx",
          (unsigned long long)a1, (unsigned long long)a2);
    BOOL inserted = WXInsertLocalNotice(a2);
    WXLog(@"RevokeInChat: insert notice=%d", inserted ? 1 : 0);
    return 1;
}

static BOOL WXIsTargetDylibPath(NSString *imagePath) {
    if (imagePath.length == 0) return NO;
    return [imagePath hasSuffix:@"/Contents/Resources/wechat.dylib"] ||
           ([imagePath containsString:@"/Contents/Resources/"] &&
            [[imagePath lastPathComponent] isEqualToString:@"wechat.dylib"]);
}

static BOOL WXInstallPointerHook(intptr_t slide, NSString *source) {
    if (g_hookInstalled) return YES;
    if (!g_profile) return NO;

    g_dylibSlide = (uintptr_t)slide;

    if (WXRevokeHandlerIsStaticPatched()) {
        WXLog(@"RevokeInChat: revoke handler has static patch (RecallGuard); "
              @"in-chat marker needs reinstall: bash install.sh --with-framework");
        return NO;
    }

    uintptr_t slot = WXRuntimePtr(g_profile->hookPointerVA);
    uintptr_t hookFn = (uintptr_t)&WXHandleSysMsgRevokeHook;

    WXLog(@"RevokeInChat: install from %@ slide=0x%lx slot=0x%lx hook=0x%lx",
          source, (unsigned long)g_dylibSlide, (unsigned long)slot, (unsigned long)hookFn);

    if (!WXWritePointer(slot, hookFn)) {
        return NO;
    }
    g_hookInstalled = YES;
    return YES;
}

static void WXOnImageAdded(const struct mach_header *mh, intptr_t slide) {
    (void)mh;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *path = [NSString stringWithUTF8String:name];
        if (!WXIsTargetDylibPath(path)) continue;
        intptr_t imageSlide = _dyld_get_image_vmaddr_slide(i);
        if (WXInstallPointerHook(imageSlide, @"dyld add image")) {
            return;
        }
    }
    WXInstallPointerHook(slide, @"dyld add image fallback");
}

static BOOL WXScanLoadedDylib(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *path = [NSString stringWithUTF8String:name];
        if (!WXIsTargetDylibPath(path)) continue;
        intptr_t slide = _dyld_get_image_vmaddr_slide(i);
        if (WXInstallPointerHook(slide, @"dyld scan")) {
            return YES;
        }
    }
    return NO;
}

static const WXRevokeProfile *WXProfileForCurrentWeChat(void) {
#if defined(__x86_64__)
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (![build isKindOfClass:[NSString class]]) return NULL;
    if ([build isEqualToString:@(kProfile269077.buildVersion)]) {
        return &kProfile269077;
    }
#endif
    return NULL;
}

void WXInstallRevokeInChat(void) {
    if (!WXModuleEnabled(@"recallInChat")) {
        WXLog(@"RevokeInChat: module disabled");
        return;
    }

    g_profile = WXProfileForCurrentWeChat();
    if (!g_profile) {
        WXLog(@"RevokeInChat: no profile for this WeChat build/arch");
        return;
    }

    WXLog(@"RevokeInChat: profile build=%s", g_profile->buildVersion);

    if (WXScanLoadedDylib()) {
        return;
    }

    _dyld_register_func_for_add_image(WXOnImageAdded);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (!g_hookInstalled) {
            WXScanLoadedDylib();
        }
    });
}
