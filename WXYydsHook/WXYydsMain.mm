// wxyyds Framework v0.5.0 — 菜单 + 撤回提醒 + FreezeLock
// 防撤回核心仍靠 install.sh 静态 Patch（RecallGuard）
// 聊天内灰字提示（insertPaySysMsgToSession）待按版本 RE，参考 SovietExtension

#import "WXCommon.h"

void WXInstallFreezeLock(void);
void WXInstallRecallNotify(void);
void WXInstallMenuManager(void);
void WXInstallExitWatch(void);
void WXInstallOpenLink(void);

__attribute__((constructor))
static void wxyyds_init(void) {
    WXLog(@"WXYydsHook v0.5.0 — %@", [[NSBundle mainBundle] bundlePath]);
    dispatch_async(dispatch_get_main_queue(), ^{
        WXInstallMenuManager();
        WXInstallFreezeLock();
        WXInstallRecallNotify();
        WXInstallExitWatch();
        WXInstallOpenLink();
    });
}
