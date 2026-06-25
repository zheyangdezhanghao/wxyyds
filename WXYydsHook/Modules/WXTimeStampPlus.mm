#import "WXCommon.h"
#import "WXSwizzle.h"
#import <atomic>

static std::atomic<bool> g_tsInstalled(false);

static NSString *WXFormatTimestampFromWrap(id wrap) {
    if (!wrap) return @"";
    uint64_t ms = 0;
    if ([wrap respondsToSelector:@selector(m_uiCreateTime)]) {
        ms = (uint64_t)[wrap performSelector:@selector(m_uiCreateTime)];
    }
    if (ms == 0) return @"";

    NSTimeInterval sec = ms > 10000000000 ? ms / 1000.0 : (NSTimeInterval)ms;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:sec];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [fmt stringFromDate:date];
}

static void WXTryEnableBuiltinTimestampFlag(void) {
    // WeChat 内部配置键（字符串存在于 wechat.dylib）
    for (NSString *key in @[
        @"clicfg_xwechat_message_ui_timestamp",
        @"xwechat_message_ui_timestamp",
        @"message_ui_timestamp",
    ]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    WXLog(@"TimeStamp+ enabled builtin flags where available");
}

void WXInstallTimeStampPlus(void) {
    if (!WXModuleEnabled(@"timeStampPlus")) return;
    if (g_tsInstalled.exchange(true)) return;

    WXTryEnableBuiltinTimestampFlag();

    __block int hooked = 0;
    NSArray<NSString *> *patterns = @[
        @"UpdateMessageCell", @"configMessageCell", @"setMessageData", @"reloadMessage",
    ];

    for (NSString *pattern in patterns) {
        hooked += WXSwizzleMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
            IMP wrapper = imp_implementationWithBlock(^void(id self, id wrap) {
                NSString *ts = WXFormatTimestampFromWrap(wrap);
                if (ts.length > 0 && [self respondsToSelector:@selector(setToolTip:)]) {
                    [self performSelector:@selector(setToolTip:) withObject:ts];
                }
                if (originalIMP) {
                    ((void (*)(id, SEL, id))originalIMP)(self, sel, wrap);
                }
            });
            method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
        }, NULL);
    }

    WXLog(@"TimeStamp+ installed (%d hooks)", hooked);
}
