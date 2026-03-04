import Intents

class IntentHandler: INExtension, INPlayMediaIntentHandling {

  // MARK: - Resolution

  func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
    // Create a pass-through media item carrying the search term.
    // Actual search/playback is handled by the main app after .handleInApp.
    let searchTerm = intent.mediaSearch?.mediaName ?? ""
    let mediaItem = INMediaItem(
      identifier: searchTerm,
      title: searchTerm,
      type: .song,
      artwork: nil
    )
    completion([.success(with: mediaItem)])
  }

  // MARK: - Handle

  func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
    completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
  }
}
