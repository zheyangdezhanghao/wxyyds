#import "WXCommon.h"
#import <AppKit/AppKit.h>

@interface WXMenuManager : NSObject
+ (void)installMenuItems;
+ (void)toggleModule:(NSMenuItem *)sender;
+ (void)openMultiInstance:(id)sender;
@end

static BOOL g_menuInstalled = NO;

static NSMenuItem *WXMakeToggleItem(NSString *title, NSString *moduleKey, SEL action) {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = [WXMenuManager class];
    item.state = WXModuleEnabled(moduleKey) ? NSControlStateValueOn : NSControlStateValueOff;
    item.representedObject = moduleKey;
    return item;
}

@interface WXMenuManager ()
@end

@implementation WXMenuManager

+ (void)toggleModule:(NSMenuItem *)sender {
    NSString *key = sender.representedObject;
    if (![key isKindOfClass:[NSString class]]) return;
    BOOL next = sender.state != NSControlStateValueOn;
    WXSetModuleEnabled(key, next);
    sender.state = next ? NSControlStateValueOn : NSControlStateValueOff;
    WXLog(@"Menu toggle %@ -> %@", key, next ? @"ON" : @"OFF");
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"wxyyds";
    alert.informativeText = @"部分功能需重启微信后生效。";
    [alert addButtonWithTitle:@"好的"];
    [alert runModal];
}

+ (void)openMultiInstance:(id)sender {
    (void)sender;
    NSString *app = [[NSBundle mainBundle] bundlePath];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[@"-n", app];
    [task launch];
}

+ (void)installMenuItems {
    if (g_menuInstalled) return;
    NSApplication *app = [NSApplication sharedApplication];
    NSMenu *mainMenu = app.mainMenu;
    if (!mainMenu) {
        WXLog(@"MenuManager: mainMenu not ready");
        return;
    }
    for (NSMenuItem *item in mainMenu.itemArray) {
        if ([item.title isEqualToString:@"wxyyds 助手"]) {
            g_menuInstalled = YES;
            return;
        }
    }

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"wxyyds 助手"];
    [menu addItem:WXMakeToggleItem(@"阻止更新", @"freezeLock", @selector(toggleModule:))];
    [menu addItem:WXMakeToggleItem(@"撤回提醒", @"recallNotify", @selector(toggleModule:))];
    [menu addItem:WXMakeToggleItem(@"退群监控", @"exitWatch", @selector(toggleModule:))];
    [menu addItem:WXMakeToggleItem(@"使用系统浏览器", @"openLink", @selector(toggleModule:))];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *multi = [[NSMenuItem alloc] initWithTitle:@"多开" action:@selector(openMultiInstance:) keyEquivalent:@""];
    multi.target = [WXMenuManager class];
    [menu addItem:multi];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *ver = [[NSMenuItem alloc] initWithTitle:@"当前版本 0.5.0" action:nil keyEquivalent:@""];
    ver.enabled = NO;
    [menu addItem:ver];

    NSMenuItem *top = [[NSMenuItem alloc] initWithTitle:@"wxyyds 助手" action:nil keyEquivalent:@""];
    top.submenu = menu;
    [mainMenu addItem:top];
    g_menuInstalled = YES;
    WXLog(@"MenuManager: wxyyds 助手 menu installed");
}

@end

void WXInstallMenuManager(void) {
    if (!WXModuleEnabled(@"menuBar")) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [WXMenuManager installMenuItems];
    });
}
