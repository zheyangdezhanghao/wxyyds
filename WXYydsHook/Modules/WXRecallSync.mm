#import "WXCommon.h"
#import "WXSwizzle.h"

static NSMutableSet<NSString *> *g_syncHooked;

static void WXAppendRecallSyncLog(NSString *line) {
    NSString *path = @"/tmp/wxyyds-recall-sync.log";
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], line];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    }
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

static NSString *WXExtractMessageText(id arg) {
    if (!arg) return @"";
    if ([arg isKindOfClass:[NSString class]]) return (NSString *)arg;
    if ([arg respondsToSelector:@selector(m_nsContent)]) {
        id c = [arg performSelector:@selector(m_nsContent)];
        if ([c isKindOfClass:[NSString class]]) return c;
    }
    if ([arg respondsToSelector:@selector(content)]) {
        id c = [arg performSelector:@selector(content)];
        if ([c isKindOfClass:[NSString class]]) return c;
    }
    return [arg description] ?: @"";
}

static void WXSyncRevokePayload(NSString *summary) {
    NSString *payload = summary.length ? summary : @"[撤回消息]";
    WXAppendRecallSyncLog(payload);

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:[NSString stringWithFormat:@"[wxyyds RecallSync]\n%@", payload]
         forType:NSPasteboardTypeString];

    WXNotify(@"wxyyds · RecallSync",
             @"撤回内容已写入剪贴板与 /tmp/wxyyds-recall-sync.log，可粘贴到「文件传输助手」。");
}

void WXInstallRecallSync(void) {
    if (!WXModuleEnabled(@"recallSync")) return;
    if (!g_syncHooked) g_syncHooked = [NSMutableSet set];

    NSArray<NSString *> *patterns = @[@"OnMessageRevoke", @"OnMessageRevoked"];
    __block int hooked = 0;
    for (NSString *pattern in patterns) {
        hooked += WXSwizzleMethodsMatching(pattern, ^(Class cls, SEL sel, IMP originalIMP) {
            NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
            if ([g_syncHooked containsObject:key]) return;
            [g_syncHooked addObject:key];
            IMP wrapper = imp_implementationWithBlock(^void(id self, id arg1) {
                NSString *text = WXExtractMessageText(arg1);
                WXSyncRevokePayload(text);
                if (originalIMP) {
                    ((void (*)(id, SEL, id))originalIMP)(self, sel, arg1);
                }
            });
            method_setImplementation(class_getInstanceMethod(cls, sel), wrapper);
        }, NULL);
    }

    WXLog(@"RecallSync installed (%d hooks)", hooked);
}
