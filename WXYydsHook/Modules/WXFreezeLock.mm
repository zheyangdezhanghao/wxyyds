#import "WXCommon.h"
#import "WXSwizzle.h"
#import <objc/runtime.h>
#import <atomic>

static std::atomic<bool> g_freezeInstalled(false);

static void wx_block_updater(Class cls, SEL sel) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP blockImp = imp_implementationWithBlock(^(id self) {
        WXLog(@"FreezeLock blocked -[%@ %@]", [self class], NSStringFromSelector(sel));
    });
    method_setImplementation(m, blockImp);
}

static void wx_block_bool_false(Class cls, SEL sel) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP imp = imp_implementationWithBlock(^BOOL(id self) {
        WXLog(@"FreezeLock blocked (NO) -[%@ %@]", [self class], NSStringFromSelector(sel));
        return NO;
    });
    method_setImplementation(m, imp);
}

void WXInstallFreezeLock(void) {
    if (!WXModuleEnabled(@"freezeLock")) {
        WXLog(@"FreezeLock disabled in config");
        return;
    }
    if (g_freezeInstalled.exchange(true)) return;

    const char *selectors[] = {
        "checkForUpdates:",
        "checkForUpdatesInBackground",
        "enableAutoUpdate:",
        "startUpdater",
        NULL
    };

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        const char *name = class_getName(cls);
        if (!strstr(name, "Sparkle") && !strstr(name, "SPU") && !strstr(name, "Updater")) {
            continue;
        }
        for (int s = 0; selectors[s]; s++) {
            SEL sel = sel_registerName(selectors[s]);
            if (class_getInstanceMethod(cls, sel)) {
                wx_block_updater(cls, sel);
            }
        }
        wx_block_bool_false(cls, sel_registerName("automaticallyDownloadsUpdates"));
        wx_block_bool_false(cls, sel_registerName("canCheckForUpdate"));
    }
    free(classes);

    for (NSString *cn in @[@"AppDelegate", @"WeChatAppDelegate", @"MMAppDelegate"]) {
        Class cls = NSClassFromString(cn);
        if (!cls) continue;
        wx_block_updater(cls, sel_registerName("checkForUpdates:"));
        wx_block_updater(cls, sel_registerName("initSparkleConfigIfNeeded"));
    }
    WXLog(@"FreezeLock installed");
}
