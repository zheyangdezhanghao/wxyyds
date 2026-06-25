#import "WXCommon.h"
#import "WXSwizzle.h"
#import <atomic>

static std::atomic<bool> g_ghostInstalled(false);

static BOOL WXLooksLikeDeletedContactEvent(NSString *text) {
    if (text.length == 0) return NO;
    NSArray<NSString *> *patterns = @[
        @"开启了朋友验证", @"已不是好友", @"被拉黑", @"删除了好友",
    ];
    for (NSString *p in patterns) {
        if ([text rangeOfString:p].location != NSNotFound) return YES;
    }
    return NO;
}

static NSString *WXGhostTextFrom(id obj) {
    if (!obj) return @"";
    if ([obj isKindOfClass:[NSString class]]) return (NSString *)obj;
    if ([obj respondsToSelector:@selector(m_nsUsrName)]) {
        id u = [obj performSelector:@selector(m_nsUsrName)];
        if ([u isKindOfClass:[NSString class]]) return u;
    }
  if ([obj respondsToSelector:@selector(m_nsNickName)]) {
        id n = [obj performSelector:@selector(m_nsNickName)];
        if ([n isKindOfClass:[NSString class]]) return n;
    }
    return [obj description] ?: @"";
}

void WXInstallGhostCheck(void) {
    if (!WXModuleEnabled(@"ghostCheck")) return;
    if (g_ghostInstalled.exchange(true)) return;

    NSArray<NSString *> *patterns = @[
        @"OnSyncBatchAddMsgs", @"OnContactUpdate", @"UpdateContact", @"ModContact",
    ];
    __block int hooked = 0;

    for (NSString *pattern in patterns) {
        hooked += WXSwizzleMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
            IMP wrapper = imp_implementationWithBlock(^void(id self, id arg1, id arg2) {
                NSString *t1 = WXGhostTextFrom(arg1);
                NSString *t2 = WXGhostTextFrom(arg2);
                if (WXLooksLikeDeletedContactEvent(t1) || WXLooksLikeDeletedContactEvent(t2)) {
                    NSString *msg = WXLooksLikeDeletedContactEvent(t1) ? t1 : t2;
                    WXNotify(@"wxyyds · GhostCheck", msg);
                    WXLog(@"GhostCheck: %@", msg);
                }
                if (originalIMP) {
                    ((void (*)(id, SEL, id, id))originalIMP)(self, sel, arg1, arg2);
                }
            });
            method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
        }, NULL);
    }

    WXLog(@"GhostCheck installed (%d hooks)", hooked);
}
