#pragma once

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^WXMethodHookBlock)(id self, SEL _cmd);

void WXSwizzleInstance(Class cls, SEL sel, IMP newImp, IMP * _Nullable originalOut);
int WXSwizzleMethodsMatching(NSString *selectorSubstring,
                             void (^before)(Class cls, SEL sel, IMP originalIMP),
                             IMP replacementIMP);
int WXEnumerateLoadedClasses(void (^block)(Class cls));
int WXCountMethodsMatching(NSString *selectorSubstring);
void WXLogRuntimeSelectorMatches(NSString *selectorSubstring);
BOOL WXImpIsInWeChatDylib(IMP imp);
int WXSwizzleWeChatMethodsMatching(NSString *selectorSubstring,
                                   void (^before)(Class cls, SEL sel, IMP originalIMP));
void WXLogWeChatSelectorMatches(NSString *selectorSubstring, int maxLog);

NS_ASSUME_NONNULL_END
