// wxyyds — 稳定 Framework：仅 FreezeLock（禁自动更新）
// 防撤回请使用 install.sh --patch-only（静态 Patch，不注入 Framework）

#import "WXCommon.h"

void WXInstallFreezeLock(void);

__attribute__((constructor))
static void wxyyds_init(void) {
    WXLog(@"WXYydsHook v0.4.1 (stability) — %@", [[NSBundle mainBundle] bundlePath]);
    dispatch_async(dispatch_get_main_queue(), ^{
        WXInstallFreezeLock();
    });
}
