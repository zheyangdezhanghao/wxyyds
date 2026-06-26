#import "WXCommon.h"
#import "WXSwizzle.h"
#import <objc/message.h>

static NSMutableSet<NSString *> *g_markerHooked;
static NSMutableSet<NSString *> *g_recentRevokeKeys;

static NSString *WXHookKey(Class cls, SEL sel) {
    return [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
}

static NSString *WXRevokeKey(NSString *xml) {
    NSString *msgId = @"";
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"<newmsgid>([^<]+)</newmsgid>"
                                                                      options:0
                                                                        error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    if (m.numberOfRanges > 1) {
        msgId = [xml substringWithRange:[m rangeAtIndex:1]];
    }
    if (msgId.length == 0) {
        msgId = [NSString stringWithFormat:@"%lu", (unsigned long)xml.hash];
    }
    return msgId;
}

static BOOL WXContainsRevokeXML(NSString *text) {
    if (text.length == 0) return NO;
    NSString *lower = text.lowercaseString;
    return ([lower containsString:@"revokemsg"] ||
            ([lower containsString:@"<sysmsg"] && [lower containsString:@"replacemsg"]));
}

static NSString *WXExtractXMLTag(NSString *xml, NSString *tag) {
    NSString *pattern = [NSString stringWithFormat:@"<%@>([^<]*)</%@>", tag, tag];
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                      options:0
                                                                        error:nil];
    NSTextCheckingResult *m = [re firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    if (m.numberOfRanges > 1) {
        return [xml substringWithRange:[m rangeAtIndex:1]];
    }
    return @"";
}

static NSString *WXScanObjectForRevokeXML(id obj, int depth) {
    if (!obj || depth > 3) return @"";
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)obj;
        return WXContainsRevokeXML(s) ? s : @"";
    }
    if ([obj isKindOfClass:[NSData class]]) {
        NSString *s = [[NSString alloc] initWithData:(NSData *)obj encoding:NSUTF8StringEncoding];
        if (s.length && WXContainsRevokeXML(s)) return s;
    }
    if ([obj respondsToSelector:@selector(m_nsContent)]) {
        id c = ((id (*)(id, SEL))objc_msgSend)(obj, @selector(m_nsContent));
        if ([c isKindOfClass:[NSString class]] && WXContainsRevokeXML(c)) return c;
    }
    if ([obj respondsToSelector:@selector(content)]) {
        id c = ((id (*)(id, SEL))objc_msgSend)(obj, @selector(content));
        if ([c isKindOfClass:[NSString class]] && WXContainsRevokeXML(c)) return c;
    }
    NSString *desc = [obj description];
    if (WXContainsRevokeXML(desc)) return desc;
    return @"";
}

static NSString *WXScanArgsForRevokeXML(va_list args, int maxArgs) {
    for (int i = 0; i < maxArgs; i++) {
        id arg = va_arg(args, id);
        NSString *xml = WXScanObjectForRevokeXML(arg, 0);
        if (xml.length) return xml;
    }
    return @"";
}

static void WXShowRevokeMarker(NSString *xml) {
    if (!g_recentRevokeKeys) g_recentRevokeKeys = [NSMutableSet set];
    NSString *key = WXRevokeKey(xml);
    if ([g_recentRevokeKeys containsObject:key]) return;
    [g_recentRevokeKeys addObject:key];
    if (g_recentRevokeKeys.count > 200) {
        [g_recentRevokeKeys removeAllObjects];
        [g_recentRevokeKeys addObject:key];
    }

    NSString *replace = WXExtractXMLTag(xml, @"replacemsg");
    NSString *revoker = WXExtractXMLTag(xml, @"fromusername");
    NSString *body = @"⚠️ wxyyds 已拦截撤回消息";
    if (replace.length > 0) {
        body = [NSString stringWithFormat:@"⚠️ wxyyds 已拦截撤回\n%@", replace];
    } else if (revoker.length > 0) {
        body = [NSString stringWithFormat:@"⚠️ %@ 试图撤回消息（已拦截）", revoker];
    }

    WXLog(@"RecallMarker: %@", body);
    WXNotify(@"wxyyds · 撤回标记", body);
}

static void WXInstallRevokeArgScanner(NSString *pattern) {
    WXSwizzleWeChatMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
        NSString *key = WXHookKey(cls, sel);
        if ([g_markerHooked containsObject:key]) return;
        [g_markerHooked addObject:key];

        IMP wrapper = imp_implementationWithBlock(^void(id self, id arg1, id arg2, id arg3) {
            NSString *xml = WXScanObjectForRevokeXML(arg1, 0);
            if (xml.length == 0) xml = WXScanObjectForRevokeXML(arg2, 0);
            if (xml.length == 0) xml = WXScanObjectForRevokeXML(arg3, 0);
            if (xml.length > 0) {
                WXShowRevokeMarker(xml);
            }
            if (originalIMP) {
                ((void (*)(id, SEL, id, id, id))originalIMP)(self, sel, arg1, arg2, arg3);
            }
        });
        method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
    });
}

void WXInstallRecallNotify(void) {
    if (!WXModuleEnabled(@"recallNotify")) return;
    if (!g_markerHooked) g_markerHooked = [NSMutableSet set];

    if (g_markerHooked.count == 0) {
        WXLogWeChatSelectorMatches(@"Revoke", 15);
        WXLogWeChatSelectorMatches(@"SysMsg", 15);
        WXLogWeChatSelectorMatches(@"Sync", 15);
    }

    NSArray<NSString *> *patterns = @[
        @"OnMessageRevoke", @"OnMessageRevoked", @"MessageRevoke",
        @"UpdateUiRevoke", @"HandleRevoke", @"RevokeMsg", @"revokemsg",
        @"SysMsg", @"HandleSync", @"AddMsg", @"AddLocal", @"InsertMsg",
        @"DelMsg", @"DeleteMsg", @"CoHandleSync",
    ];

    __block int total = 0;
    for (NSString *pattern in patterns) {
        WXInstallRevokeArgScanner(pattern);
        total = (int)g_markerHooked.count;
    }

    WXLog(@"RecallNotify/RecallMarker installed (%d wechat hooks)", total);
}
