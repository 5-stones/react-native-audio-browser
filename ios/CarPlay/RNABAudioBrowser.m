#import "RNABAudioBrowser.h"

@implementation RNABAudioBrowser

+ (void)handleMediaIntent:(INIntent *)intent completionHandler:(void (^)(INIntentResponse *))completionHandler {
    Class cls = NSClassFromString(@"RNABMediaIntentHandler");
    SEL sel = NSSelectorFromString(@"handleMediaIntent:completionHandler:");
    if (cls && [cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // RNABMediaIntentHandler.handleMediaIntent(_:completionHandler:) is a static @objc method
        // that handles INPlayMediaIntent search and playback.
        typedef void (*HandleFn)(id, SEL, INIntent *, void (^)(INIntentResponse *));
        HandleFn fn = (HandleFn)[cls methodForSelector:sel];
        fn(cls, sel, intent, completionHandler);
#pragma clang diagnostic pop
    } else {
        completionHandler([[INPlayMediaIntentResponse alloc] initWithCode:INPlayMediaIntentResponseCodeFailureRequiringAppLaunch userActivity:nil]);
    }
}

@end
