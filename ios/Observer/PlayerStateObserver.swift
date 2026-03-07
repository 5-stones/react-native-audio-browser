import AVFoundation
import Foundation

/**
 Observes player state changes and invokes callbacks passed at initialization.
 Uses modern block-based KVO for type-safe observation with automatic cleanup.
 */
@MainActor final class PlayerStateObserver {
  private var observations: [NSKeyValueObservation] = []

  weak var avPlayer: AVPlayer? {
    willSet {
      stopObserving()
    }
  }

  private let onStatusChange: @MainActor (AVPlayer.Status) -> Void
  private let onTimeControlStatusChange: @MainActor (AVPlayer.TimeControlStatus) -> Void

  init(
    onStatusChange: @escaping @MainActor (AVPlayer.Status) -> Void,
    onTimeControlStatusChange: @escaping @MainActor (AVPlayer.TimeControlStatus) -> Void,
  ) {
    self.onStatusChange = onStatusChange
    self.onTimeControlStatusChange = onTimeControlStatusChange
  }

  /**
   Start receiving events from this observer.
   */
  func startObserving() {
    guard let avPlayer else { return }
    stopObserving()

    observations = [
      avPlayer.observe(\.status, options: [.new, .initial]) { [weak self] player, _ in
        let status = player.status
        Task { @MainActor in self?.onStatusChange(status) }
      },
      avPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
        let status = player.timeControlStatus
        Task { @MainActor in self?.onTimeControlStatusChange(status) }
      },
    ]
  }

  func stopObserving() {
    observations.removeAll()
  }
}
