// 聊天内撤回标记 — 暂未启用（运行时 patch wechat.dylib 会触发反篡改导致登录后退出）
#import "WXCommon.h"

void WXInstallRevokeMarker(void) {
    if (!WXModuleEnabled(@"recallNotify")) return;
    WXLog(@"RevokeMarker: disabled (use patch-only RecallGuard; in-chat marker pending RE)");
}
