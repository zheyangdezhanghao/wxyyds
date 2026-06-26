// wxyyds Framework v0.6.0 — 菜单 + 撤回提醒 + 聊天内灰字 + FreezeLock
// Intel 269077：Framework 模式用指针 Hook + insertPaySysMsgToSession（跳过 revoke 静态 Patch）

#import "WXCommon.h"

void WXInstallFreezeLock(void);
void WXInstallRecallNotify(void);
void WXInstallRevokeInChat(void);
void WXInstallMenuManager(void);
void WXInstallExitWatch(void);
void WXInstallOpenLink(void);

__attribute__((constructor))
static void wxyyds_init(void) {
    WXLog(@"WXYydsHook v0.6.0 — %@", [[NSBundle mainBundle] bundlePath]);
    dispatch_async(dispatch_get_main_queue(), ^{
        WXInstallMenuManager();
        WXInstallFreezeLock();
        WXInstallRecallNotify();
        WXInstallRevokeInChat();
        WXInstallExitWatch();
        WXInstallOpenLink();
    });
}
