#import "WXCommon.h"
#import "WXSwizzle.h"
#import <atomic>

static std::atomic<bool> g_openLinkInstalled(false);
static IMP g_origOpenURL = NULL;
static IMP g_origOpenURLConfig = NULL;
static thread_local BOOL g_openLinkForwarding = NO;

static BOOL WXIsHttpURL(id urlObj) {
    if (![urlObj isKindOfClass:[NSURL class]]) return NO;
    NSURL *url = (NSURL *)urlObj;
    NSString *scheme = url.scheme.lowercaseString;
    return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

static BOOL WXCallstackLooksLikeWeChat(void) {
    NSArray<NSString *> *symbols = [NSThread callStackSymbols];
    for (NSString *s in symbols) {
        if ([s rangeOfString:@"WeChat" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [s rangeOfString:@"wechat.dylib" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL WXCallOrigOpenURL(NSWorkspace *workspace, NSURL *url) {
    if (!g_origOpenURL || !url) return NO;
    return ((BOOL (*)(id, SEL, NSURL *))g_origOpenURL)(workspace, @selector(openURL:), url);
}

static void WXCallOrigOpenURLConfig(NSWorkspace *workspace, NSURL *url, id config, id handler) {
    if (!g_origOpenURLConfig || !url) return;
    ((void (*)(id, SEL, NSURL *, id, id))g_origOpenURLConfig)(
        workspace, @selector(openURL:configuration:completionHandler:), url, config, handler);
}

static void WXOpenInSystemBrowser(NSURL *url) {
    if (!url || g_openLinkForwarding) return;
    g_openLinkForwarding = YES;
    WXLog(@"OpenLink: %@", url.absoluteString);
    WXCallOrigOpenURL([NSWorkspace sharedWorkspace], url);
    g_openLinkForwarding = NO;
}

void WXInstallOpenLink(void) {
    if (!WXModuleEnabled(@"openLink")) return;
    if (g_openLinkInstalled.exchange(true)) return;

    Class ws = [NSWorkspace class];
    SEL sel1 = @selector(openURL:);
    SEL sel2 = @selector(openURL:configuration:completionHandler:);

    Method m1 = class_getInstanceMethod(ws, sel1);
    if (m1) {
        g_origOpenURL = method_getImplementation(m1);
        IMP hook1 = imp_implementationWithBlock(^BOOL(id self, NSURL *url) {
            if (g_openLinkForwarding) {
                return WXCallOrigOpenURL((NSWorkspace *)self, url);
            }
            if (WXIsHttpURL(url) && WXCallstackLooksLikeWeChat()) {
                WXOpenInSystemBrowser(url);
                return YES;
            }
            return WXCallOrigOpenURL((NSWorkspace *)self, url);
        });
        method_setImplementation(m1, hook1);
        WXLog(@"OpenLink hooked -[NSWorkspace openURL:]");
    }

    if (@available(macOS 10.15, *)) {
        Method m2 = class_getInstanceMethod(ws, sel2);
        if (m2) {
            g_origOpenURLConfig = method_getImplementation(m2);
            IMP hook2 = imp_implementationWithBlock(^void(id self, NSURL *url, id config, id handler) {
                if (g_openLinkForwarding) {
                    WXCallOrigOpenURLConfig((NSWorkspace *)self, url, config, handler);
                    return;
                }
                if (WXIsHttpURL(url) && WXCallstackLooksLikeWeChat()) {
                    WXOpenInSystemBrowser(url);
                    if (handler) {
                        ((void (^)(id, NSError *))handler)(nil, nil);
                    }
                    return;
                }
                WXCallOrigOpenURLConfig((NSWorkspace *)self, url, config, handler);
            });
            method_setImplementation(m2, hook2);
            WXLog(@"OpenLink hooked -[NSWorkspace openURL:configuration:completionHandler:]");
        }
    }

    __block int extra = 0;
    extra += WXSwizzleMethodsMatching(@"openURLWithDefaultBrowser", ^(Class cls, SEL sel, IMP originalIMP) {
        IMP wrapper = imp_implementationWithBlock(^void(id self, NSURL *url) {
            if (WXIsHttpURL(url) && !g_openLinkForwarding) {
                WXOpenInSystemBrowser(url);
                return;
            }
            if (originalIMP) {
                ((void (*)(id, SEL, NSURL *))originalIMP)(self, sel, url);
            }
        });
        method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
    }, NULL);

    WXLog(@"OpenLink installed (extra hooks=%d)", extra);
}
