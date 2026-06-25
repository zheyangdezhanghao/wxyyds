#import "WXSwizzle.h"
#import "WXCommon.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>

void WXSwizzleInstance(Class cls, SEL sel, IMP newImp, IMP *originalOut) {
    if (!cls || !sel || !newImp) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    if (originalOut) *originalOut = orig;
    method_setImplementation(m, newImp);
    WXLog(@"swizzled -[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(sel));
}

int WXEnumerateLoadedClasses(void (^block)(Class cls)) {
    if (!block) return 0;
    int count = 0;
    unsigned int n = 0;
    Class *classes = objc_copyClassList(&n);
    for (unsigned int i = 0; i < n; i++) {
        block(classes[i]);
        count++;
    }
    free(classes);
    return count;
}

int WXCountMethodsMatching(NSString *selectorSubstring) {
    if (!selectorSubstring.length) return 0;
    __block int found = 0;
    WXEnumerateLoadedClasses(^(Class cls) {
        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);
        for (unsigned int i = 0; i < mc; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name rangeOfString:selectorSubstring options:NSCaseInsensitiveSearch].location != NSNotFound) {
                found++;
            }
        }
        free(methods);
    });
    return found;
}

void WXLogRuntimeSelectorMatches(NSString *selectorSubstring) {
    if (!selectorSubstring.length) return;
    __block int logged = 0;
    WXEnumerateLoadedClasses(^(Class cls) {
        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);
        for (unsigned int i = 0; i < mc; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name rangeOfString:selectorSubstring options:NSCaseInsensitiveSearch].location == NSNotFound) {
                continue;
            }
            if (logged < 20) {
                WXLog(@"selector match: -[%@ %@]", NSStringFromClass(cls), name);
            }
            logged++;
        }
        free(methods);
    });
    WXLog(@"selector '%@' matches: %d (logged max 20)", selectorSubstring, logged);
}

int WXSwizzleMethodsMatching(NSString *selectorSubstring,
                             void (^before)(Class cls, SEL sel, IMP originalIMP),
                             IMP replacementIMP) {
    if (!selectorSubstring.length || !replacementIMP) return 0;
    __block int hooked = 0;
    WXEnumerateLoadedClasses(^(Class cls) {
        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);
        for (unsigned int i = 0; i < mc; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(sel);
            if ([name rangeOfString:selectorSubstring options:NSCaseInsensitiveSearch].location == NSNotFound) {
                continue;
            }
            IMP orig = method_getImplementation(methods[i]);
            if (before) {
                before(cls, sel, orig);
            } else if (replacementIMP) {
                method_setImplementation(methods[i], replacementIMP);
            }
            if (before || replacementIMP) {
                WXLog(@"hooked -[%@ %@]", NSStringFromClass(cls), name);
                hooked++;
            }
        }
        free(methods);
    });
    return hooked;
}

BOOL WXImpIsInWeChatDylib(IMP imp) {
    if (!imp) return NO;
    Dl_info info;
    if (dladdr((void *)imp, &info) == 0 || !info.dli_fname) return NO;
    return strstr(info.dli_fname, "/WeChat.app/Contents/Resources/wechat.dylib") != NULL;
}

int WXSwizzleWeChatMethodsMatching(NSString *selectorSubstring,
                                   void (^before)(Class cls, SEL sel, IMP originalIMP)) {
    if (!selectorSubstring.length || !before) return 0;
    __block int hooked = 0;
    WXEnumerateLoadedClasses(^(Class cls) {
        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);
        for (unsigned int i = 0; i < mc; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(sel);
            if ([name rangeOfString:selectorSubstring options:NSCaseInsensitiveSearch].location == NSNotFound) {
                continue;
            }
            IMP orig = method_getImplementation(methods[i]);
            if (!WXImpIsInWeChatDylib(orig)) continue;
            before(cls, sel, orig);
            WXLog(@"wechat hook -[%@ %@]", NSStringFromClass(cls), name);
            hooked++;
        }
        free(methods);
    });
    return hooked;
}

void WXLogWeChatSelectorMatches(NSString *selectorSubstring, int maxLog) {
    if (!selectorSubstring.length) return;
    __block int logged = 0;
    __block int total = 0;
    WXEnumerateLoadedClasses(^(Class cls) {
        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);
        for (unsigned int i = 0; i < mc; i++) {
            NSString *name = NSStringFromSelector(method_getName(methods[i]));
            if ([name rangeOfString:selectorSubstring options:NSCaseInsensitiveSearch].location == NSNotFound) {
                continue;
            }
            IMP imp = method_getImplementation(methods[i]);
            if (!WXImpIsInWeChatDylib(imp)) continue;
            total++;
            if (logged < maxLog) {
                WXLog(@"wechat selector: -[%@ %@]", NSStringFromClass(cls), name);
                logged++;
            }
        }
        free(methods);
    });
    WXLog(@"wechat selector '%@' total=%d", selectorSubstring, total);
}
