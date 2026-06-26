#import "WXCommon.h"
#import <UserNotifications/UserNotifications.h>

static NSDictionary *g_cachedConfig = nil;
static dispatch_queue_t g_configQueue;

static NSString *WXConfigPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@".wxyyds/config.json"];
}

static NSMutableDictionary *WXMutableConfig(void) {
    NSString *path = WXConfigPath();
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSMutableDictionary *root;
    if (data) {
        id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        root = [json isKindOfClass:[NSMutableDictionary class]] ? json : [NSMutableDictionary dictionary];
    } else {
        root = [NSMutableDictionary dictionary];
    }
    if (![root[@"modules"] isKindOfClass:[NSMutableDictionary class]]) {
        root[@"modules"] = [NSMutableDictionary dictionary];
    }
    return root;
}

static NSDictionary *WXDefaultConfig(void) {
    return @{
        @"modules": @{
            @"menuBar": @YES,
            @"recallNotify": @YES,
            @"recallInChat": @YES,
            @"recallSync": @NO,
            @"freezeLock": @YES,
            @"exitWatch": @NO,
            @"openLink": @NO,
            @"timeStampPlus": @NO,
            @"ghostCheck": @NO,
            @"keywordAlert": @NO,
            @"foldPro": @NO,
        },
        @"keywordAlert": @{@"keywords": @[@"紧急", @"@所有人"]},
        @"foldPro": @{@"muteKeywords": @[@"免打扰", @"折叠"]},
    };
}

static NSDictionary *WXLoadConfigFresh(void) {
    NSString *path = WXConfigPath();
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return WXDefaultConfig();
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [json isKindOfClass:[NSDictionary class]] ? json : WXDefaultConfig();
}

static NSDictionary *WXLoadConfig(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_configQueue = dispatch_queue_create("com.wxyyds.config", DISPATCH_QUEUE_SERIAL);
        g_cachedConfig = WXLoadConfigFresh();
    });
    __block NSDictionary *cfg = nil;
    dispatch_sync(g_configQueue, ^{
        cfg = g_cachedConfig ?: WXDefaultConfig();
    });
    return cfg;
}

void WXSetModuleEnabled(NSString *moduleKey, BOOL enabled) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        g_configQueue = dispatch_queue_create("com.wxyyds.config", DISPATCH_QUEUE_SERIAL);
    });
    dispatch_sync(g_configQueue, ^{
        NSMutableDictionary *root = WXMutableConfig();
        NSMutableDictionary *modules = root[@"modules"];
        modules[moduleKey] = @(enabled);
        NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[WXConfigPath() stringByDeletingLastPathComponent]
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
            [data writeToFile:WXConfigPath() atomically:YES];
        }
        g_cachedConfig = [root copy];
    });
}

BOOL WXModuleEnabled(NSString *moduleKey) {
    NSDictionary *modules = WXLoadConfig()[@"modules"];
    if (![modules isKindOfClass:[NSDictionary class]]) return YES;
    id v = modules[moduleKey];
    if (v == nil) return YES;
    return [v boolValue];
}

NSString *WXConfigString(NSString *key) {
    id v = WXLoadConfig()[key];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

NSArray<NSString *> *WXConfigStringArray(NSString *key) {
    NSDictionary *root = WXLoadConfig();
    id direct = root[key];
    if ([direct isKindOfClass:[NSArray class]]) {
        return direct;
    }
    for (NSString *section in @[@"keywordAlert", @"foldPro", @"ghostCheck"]) {
        NSDictionary *sub = root[section];
        if ([sub isKindOfClass:[NSDictionary class]] && [sub[key] isKindOfClass:[NSArray class]]) {
            return sub[key];
        }
    }
    return @[];
}

void WXLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[wxyyds] %@", msg);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSString *path = @"/tmp/wxyyds-hook.log";
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    }
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

void WXNotifyOnMain(NSString *title, NSString *body) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(macOS 10.14, *)) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                                  completionHandler:nil];
            UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
            content.title = title ?: @"wxyyds";
            content.body = body ?: @"";
            content.sound = [UNNotificationSound defaultSound];
            UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                              content:content
                                                                              trigger:nil];
            [center addNotificationRequest:req withCompletionHandler:nil];
        }
    });
}

void WXNotify(NSString *title, NSString *body) {
    WXLog(@"%@ — %@", title, body);
    WXNotifyOnMain(title, body);
}
