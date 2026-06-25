#import "WXCommon.h"
#import "WXSwizzle.h"

static NSMutableSet<NSString *> *g_exitHooked;

static BOOL WXLooksLikeExitGroupMessage(NSString *text) {
    if (text.length == 0) return NO;
    NSArray<NSString *> *patterns = @[
        @"退出了群聊", @"退出群聊", @"被移出群聊", @"移出了群聊",
    ];
    for (NSString *p in patterns) {
        if ([text rangeOfString:p].location != NSNotFound) return YES;
    }
    return NO;
}

static NSString *WXExtractAnyString(id obj) {
    if (!obj) return @"";
    if ([obj isKindOfClass:[NSString class]]) return (NSString *)obj;
    if ([obj respondsToSelector:@selector(m_nsContent)]) {
        id c = [obj performSelector:@selector(m_nsContent)];
        if ([c isKindOfClass:[NSString class]]) return c;
    }
    return [obj description] ?: @"";
}

void WXInstallExitWatch(void) {
    if (!WXModuleEnabled(@"exitWatch")) return;
    if (!g_exitHooked) g_exitHooked = [NSMutableSet set];

    NSArray<NSString *> *patterns = @[
        @"OnSyncBatchAddMsgs", @"AddMsg:", @"OnAddMsg:", @"HandleSysMsg",
    ];
    __block int hooked = 0;

    for (NSString *pattern in patterns) {
        hooked += WXSwizzleMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
            NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
            if ([g_exitHooked containsObject:key]) return;
            [g_exitHooked addObject:key];
            IMP wrapper = imp_implementationWithBlock(^void(id self, id arg1, id arg2) {
                NSString *t1 = WXExtractAnyString(arg1);
                NSString *t2 = WXExtractAnyString(arg2);
                if (WXLooksLikeExitGroupMessage(t1) || WXLooksLikeExitGroupMessage(t2)) {
                    NSString *msg = WXLooksLikeExitGroupMessage(t1) ? t1 : t2;
                    WXNotify(@"wxyyds · ExitWatch", msg);
                    WXLog(@"ExitWatch: %@", msg);
                }
                if (originalIMP) {
                    ((void (*)(id, SEL, id, id))originalIMP)(self, sel, arg1, arg2);
                }
            });
            method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
        }, NULL);
    }

    WXLog(@"ExitWatch installed (%d hooks)", hooked);
}
