#pragma once

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

void WXLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
void WXNotify(NSString *title, NSString *body);
void WXNotifyOnMain(NSString *title, NSString *body);
BOOL WXModuleEnabled(NSString *moduleKey);
void WXSetModuleEnabled(NSString *moduleKey, BOOL enabled);
NSString * _Nullable WXConfigString(NSString *key);
NSArray<NSString *> *WXConfigStringArray(NSString *key);

NS_ASSUME_NONNULL_END
