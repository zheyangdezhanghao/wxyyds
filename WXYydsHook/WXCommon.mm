#import "WXCommon.h"
#import <UserNotifications/UserNotifications.h>

static NSDictionary *WXLoadConfig(void) {
    static NSDictionary *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@".wxyyds/config.json"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) {
            cached = @{
                @"modules": @{
                    @"recallNotify": @YES,
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
            return;
        }
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        cached = [json isKindOfClass:[NSDictionary class]] ? json : @{};
    });
    return cached;
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
