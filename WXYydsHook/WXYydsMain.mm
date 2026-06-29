// wxyyds Framework v0.6.1 — OpenLink 递归修复；模块缺省值与 config 默认对齐

#import "WXCommon.h"
#import "WXVersion.h"

void WXInstallFreezeLock(void);
void WXInstallRecallNotify(void);
void WXInstallRevokeInChat(void);
void WXInstallMenuManager(void);
void WXInstallExitWatch(void);
void WXInstallOpenLink(void);

__attribute__((constructor))
static void wxyyds_init(void) {
    WXLog(@"WXYydsHook v" WXYyds_VERSION " — %@", [[NSBundle mainBundle] bundlePath]);
    dispatch_async(dispatch_get_main_queue(), ^{
        WXInstallMenuManager();
        WXInstallFreezeLock();
        WXInstallRecallNotify();
        WXInstallRevokeInChat();
        WXInstallExitWatch();
        WXInstallOpenLink();
    });
}
