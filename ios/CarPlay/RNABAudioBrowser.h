#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

NS_ASSUME_NONNULL_BEGIN

/// Public entry point for AudioBrowser library functionality that host apps
/// need to call from their AppDelegate or other Swift/ObjC code.
///
/// Usage (add to your bridging header: #import <AudioBrowser/RNABAudioBrowser.h>):
/// @code
/// func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
///     RNABAudioBrowser.handleMediaIntent(intent, completionHandler: completionHandler)
/// }
/// @endcode
@interface RNABAudioBrowser : NSObject

/// Handle an INPlayMediaIntent forwarded from an Intents Extension via .handleInApp.
/// Searches using the configured browser search route, queues results, and starts playback.
+ (void)handleMediaIntent:(INIntent *)intent completionHandler:(void (^)(INIntentResponse *))completionHandler;

@end

NS_ASSUME_NONNULL_END
