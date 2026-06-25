#import "WXCommon.h"
#import "WXSwizzle.h"
#import <atomic>

static std::atomic<bool> g_foldInstalled(false);

static BOOL WXSessionLooksMuted(id session) {
    if (!session) return NO;
    if ([session respondsToSelector:@selector(m_bMute)]) {
        return [session performSelector:@selector(m_bMute)] ? YES : NO;
    }
    if ([session respondsToSelector:@selector(isMuted)]) {
        return [session performSelector:@selector(isMuted)] ? YES : NO;
    }
    NSString *name = @"";
    if ([session respondsToSelector:@selector(m_nsNickName)]) {
        id n = [session performSelector:@selector(m_nsNickName)];
        if ([n isKindOfClass:[NSString class]]) name = n;
    }
    for (NSString *kw in WXConfigStringArray(@"muteKeywords")) {
        if (kw.length && [name rangeOfString:kw].location != NSNotFound) return YES;
    }
    return NO;
}

void WXInstallFoldPro(void) {
    if (!WXModuleEnabled(@"foldPro")) return;
    if (g_foldInstalled.exchange(true)) return;

    __block int hooked = 0;
    NSArray<NSString *> *patterns = @[
        @"compareSession", @"sortSession", @"CompareSession", @"sessionCompare",
    ];

    for (NSString *pattern in patterns) {
        hooked += WXSwizzleMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
            IMP wrapper = imp_implementationWithBlock(^NSInteger(id self, id a, id b) {
                BOOL aMuted = WXSessionLooksMuted(a);
                BOOL bMuted = WXSessionLooksMuted(b);
                if (aMuted != bMuted) {
                    return aMuted ? NSOrderedDescending : NSOrderedAscending;
                }
                if (originalIMP) {
                    return ((NSInteger (*)(id, SEL, id, id))originalIMP)(self, sel, a, b);
                }
                return NSOrderedSame;
            });
            method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
        }, NULL);
    }

    hooked += WXSwizzleMethodsMatching(@"ReloadSessionList", ^(Class cls, SEL sel, IMP originalIMP) {
        IMP wrapper = imp_implementationWithBlock(^void(id self) {
            WXLog(@"FoldPro: session list reload on %@", NSStringFromClass(cls));
            if (originalIMP) {
                ((void (*)(id, SEL))originalIMP)(self, sel);
            }
        });
        method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
    }, NULL);

    WXLog(@"FoldPro installed (%d hooks)", hooked);
}
