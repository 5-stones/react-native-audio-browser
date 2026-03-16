/// Protocol abstracting sleep timer for testability.
/// PlaybackCoordinator uses this instead of SleepTimerManager directly.
@MainActor protocol SleepTimerHandling: AnyObject {
  var onComplete: (() -> Void)? { get set }
  func onTrackChanged()
  func onTrackPlayedToEnd()
}
