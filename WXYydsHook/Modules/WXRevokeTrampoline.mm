// Intel x86_64 撤回拦截 + 可见标记（mmap trampoline，不 patch __TEXT 为 mov+ret）
#import "WXCommon.h"
#import <atomic>
#import <cstring>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>
#import <unistd.h>

static std::atomic<bool> g_trampolineInstalled(false);
static uint8_t g_originalPrologue[16] = {0};
static void *g_stubPage = MAP_FAILED;
static void *g_revokeTarget = NULL;

static const uintptr_t kRevokeSliceOffset = 0x4F4D4C0ULL;

static BOOL WXContainsRevokeXML(NSString *text) {
    if (text.length == 0) return NO;
    NSString *lower = text.lowercaseString;
    return [lower containsString:@"revokemsg"] ||
           ([lower containsString:@"<sysmsg"] && [lower containsString:@"replacemsg"]);
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

static BOOL WXSafeRead(uintptr_t addr, void *out, size_t len) {
    vm_size_t n = (vm_size_t)len;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)addr, n, (vm_address_t)out, &n) == KERN_SUCCESS;
}

static NSString *WXScanForRevokeXML(uintptr_t base, size_t span) {
    if (base == 0 || span == 0) return @"";
    const size_t chunk = 4096;
    uint8_t buf[chunk];
    for (size_t off = 0; off < span; off += chunk) {
        size_t n = chunk;
        if (off + n > span) n = span - off;
        if (!WXSafeRead(base + off, buf, n)) continue;
        NSString *s = [[NSString alloc] initWithBytes:buf length:n encoding:NSUTF8StringEncoding];
        if (!s) {
            s = [[NSString alloc] initWithBytes:buf length:n encoding:NSISOLatin1StringEncoding];
        }
        if (s.length && WXContainsRevokeXML(s)) {
            NSRange r = [s rangeOfString:@"<sysmsg"];
            if (r.location != NSNotFound) {
                NSRange end = [s rangeOfString:@"</sysmsg>" options:0 range:NSMakeRange(r.location, s.length - r.location)];
                if (end.location != NSNotFound) {
                    return [s substringWithRange:NSMakeRange(r.location, end.location + end.length - r.location)];
                }
            }
            return s;
        }
    }
    return @"";
}

static void WXPresentRevokeMarker(NSString *xml) {
    NSString *replace = WXExtractXMLTag(xml, @"replacemsg");
    NSString *body = replace.length
        ? [NSString stringWithFormat:@"⚠️ 撤回已拦截\n%@", replace]
        : @"对方撤回了一条消息，原消息已保留在聊天窗口。";

    WXLog(@"RevokeTrampoline marker: %@", body);
    WXNotify(@"wxyyds · 撤回标记", body);
}

extern "C" int64_t wxyyds_revoke_handler(int64_t a1, int64_t a2) {
    NSString *xml = WXScanForRevokeXML((uintptr_t)a2, 4096);
    if (xml.length == 0 && a1) {
        xml = WXScanForRevokeXML((uintptr_t)a1, 4096);
    }
    if (xml.length > 0) {
        WXPresentRevokeMarker(xml);
    } else {
        WXPresentRevokeMarker(@"");
    }
    return 1;
}

static BOOL WXMakePageWritable(void *addr, size_t len) {
    vm_address_t page = (vm_address_t)((uintptr_t)addr & ~((uintptr_t)getpagesize() - 1));
    vm_size_t size = (vm_size_t)(((uintptr_t)addr + len + getpagesize() - 1) & ~((uintptr_t)getpagesize() - 1)) - page;
    return vm_protect(mach_task_self(), page, size, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS;
}

// x86_64 stub:
//   call handler (rdi=a1, rsi=a2 already)
//   mov rax, 1
//   ret
static bool WXBuildRevokeStub(void *page, void *handler) {
    uint8_t *p = (uint8_t *)page;
    // call rel32 at p+0, target handler
    intptr_t rel = (intptr_t)handler - (intptr_t)(p + 5);
    p[0] = 0xE8;
    memcpy(p + 1, &rel, 4);
    // mov rax, 1
    p[5] = 0x48; p[6] = 0xC7; p[7] = 0xC0;
    p[8] = 0x01; p[9] = 0x00; p[10] = 0x00; p[11] = 0x00;
    // ret
    p[12] = 0xC3;
    return true;
}

static BOOL WXInstallRevokeTrampoline(intptr_t slide) {
    if (g_trampolineInstalled.exchange(true)) return YES;

    void *target = (void *)(slide + kRevokeSliceOffset);
    g_revokeTarget = target;

    if (!WXSafeRead((uintptr_t)target, g_originalPrologue, sizeof(g_originalPrologue))) {
        WXLog(@"RevokeTrampoline: cannot read original prologue");
        g_trampolineInstalled = false;
        return NO;
    }

    // 若已是静态 patch (B8 01 00 00 00 C3)，先不重复安装
    if (g_originalPrologue[0] == 0xB8 && g_originalPrologue[5] == 0xC3) {
        WXLog(@"RevokeTrampoline: static patch detected — marker via SysMsg scan only");
        g_trampolineInstalled = false;
        return NO;
    }

    g_stubPage = mmap(NULL, 4096, PROT_READ | PROT_WRITE | PROT_EXEC,
                      MAP_PRIVATE | MAP_ANON, -1, 0);
    if (g_stubPage == MAP_FAILED) {
        WXLog(@"RevokeTrampoline: mmap failed");
        g_trampolineInstalled = false;
        return NO;
    }

    if (!WXBuildRevokeStub(g_stubPage, (void *)&wxyyds_revoke_handler)) {
        WXLog(@"RevokeTrampoline: stub build failed");
        g_trampolineInstalled = false;
        return NO;
    }

    if (!WXMakePageWritable(target, 5)) {
        WXLog(@"RevokeTrampoline: vm_protect target failed");
        g_trampolineInstalled = false;
        return NO;
    }

    int32_t rel = (int32_t)((uintptr_t)g_stubPage - ((uintptr_t)target + 5));
    uint8_t jmp[5] = {0xE9, (uint8_t)(rel), (uint8_t)(rel >> 8), (uint8_t)(rel >> 16), (uint8_t)(rel >> 24)};
    memcpy(target, jmp, sizeof(jmp));

    WXLog(@"RevokeTrampoline installed target=%p stub=%p slide=0x%lx", target, g_stubPage, (long)slide);
    return YES;
}

static BOOL WXIsWeChatResourceDylib(const char *path) {
    return path && strstr(path, "/WeChat.app/Contents/Resources/wechat.dylib");
}

static void wx_revoke_image_added(const struct mach_header *mh, intptr_t slide) {
    Dl_info info;
    if (dladdr(mh, &info) == 0 || !info.dli_fname) return;
    if (!WXIsWeChatResourceDylib(info.dli_fname)) return;
    WXLog(@"RevokeTrampoline: wechat.dylib slide=0x%lx", (long)slide);
    dispatch_async(dispatch_get_main_queue(), ^{
        WXInstallRevokeTrampoline(slide);
    });
}

__attribute__((constructor))
static void wx_revoke_trampoline_init(void) {
    if (!WXModuleEnabled(@"recallNotify")) return;
    _dyld_register_func_for_add_image(wx_revoke_image_added);
}

void WXInstallRevokeTrampolineFromMain(intptr_t slide) {
    WXInstallRevokeTrampoline(slide);
}
