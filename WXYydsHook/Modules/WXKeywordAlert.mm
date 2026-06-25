#import "WXCommon.h"
#import "WXSwizzle.h"
#import <atomic>

static std::atomic<bool> g_keywordInstalled(false);

static NSArray<NSString *> *WXKeywords(void) {
    NSArray<NSString *> *kw = WXConfigStringArray(@"keywords");
    return kw.count ? kw : @[@"紧急", @"@所有人"];
}

static BOOL WXContainsKeyword(NSString *text) {
    if (text.length == 0) return NO;
    for (NSString *kw in WXKeywords()) {
        if (kw.length && [text rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static NSString *WXKeywordTextFrom(id obj) {
    if (!obj) return @"";
    if ([obj isKindOfClass:[NSString class]]) return (NSString *)obj;
    if ([obj respondsToSelector:@selector(m_nsContent)]) {
        id c = [obj performSelector:@selector(m_nsContent)];
        if ([c isKindOfClass:[NSString class]]) return c;
    }
    return [obj description] ?: @"";
}

void WXInstallKeywordAlert(void) {
    if (!WXModuleEnabled(@"keywordAlert")) return;
    if (g_keywordInstalled.exchange(true)) return;

    NSArray<NSString *> *patterns = @[@"OnSyncBatchAddMsgs", @"AddMsg:", @"OnAddMsg:"];
    __block int hooked = 0;

    for (NSString *pattern in patterns) {
        hooked += WXSwizzleMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
            IMP wrapper = imp_implementationWithBlock(^void(id self, id arg1, id arg2) {
                NSString *t1 = WXKeywordTextFrom(arg1);
                NSString *t2 = WXKeywordTextFrom(arg2);
                NSString *hit = WXContainsKeyword(t1) ? t1 : (WXContainsKeyword(t2) ? t2 : nil);
                if (hit) {
                    WXNotify(@"wxyyds · KeywordAlert", hit);
                    WXLog(@"KeywordAlert matched: %@", hit);
                }
                if (originalIMP) {
                    ((void (*)(id, SEL, id, id))originalIMP)(self, sel, arg1, arg2);
                }
            });
            method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
        }, NULL);
    }

    WXLog(@"KeywordAlert installed (%d hooks, keywords=%@)", hooked, [WXKeywords() componentsJoinedByString:@","]);
}
