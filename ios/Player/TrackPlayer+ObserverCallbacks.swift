@preconcurrency import AVFoundation

// MARK: - Observer Callbacks

extension TrackPlayer {
  func avPlayerDidChangeTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
    // During loading, ignore stale timeControlStatus changes from old items.
    // State transitions during loading are managed by MediaLoader
    // and avItemDidUpdatePlaybackLikelyToKeepUp.
    if state == .loading { return }

    switch status {
    case .paused:
      let currentState = state
      let currentTime = currentTime
      let duration = duration
      // Ignore pauses when near track end - let handleTrackDidPlayToEndTime handle track
      // completion
      let nearTrackEnd = currentTime >= duration - 0.5 && duration > 0

      // Completely ignore pause events when near track end to avoid race with
      // handleTrackDidPlayToEndTime
      if nearTrackEnd {
        // Ignore - track completion will be handled by handleTrackDidPlayToEndTime
      } else if mediaLoader.asset == nil, currentState != .stopped {
        transition(.avPlayerPaused(hasAsset: false))
      } else if currentState != .error, currentState != .stopped {
        // Only update state, never modify playWhenReady
        // playWhenReady represents user intent and should only change via explicit user actions
        if !playWhenReady {
          transition(.avPlayerPaused(hasAsset: true))
        }
        // If playWhenReady is true, this is likely buffering/seeking - don't change state
      }
    case .waitingToPlayAtSpecifiedRate:
      if mediaLoader.asset != nil {
        transition(.avPlayerWaiting)
      }
    case .playing:
      transition(.avPlayerPlaying)
    @unknown default:
      break
    }
  }

  func avPlayerStatusDidChange(_ status: AVPlayer.Status) {
    if status == .failed {
      errorHandler.handleError(avPlayer.currentItem?.error, context: .playback)
    }
  }

  /// Handles AVPlayerItem status changes - this catches errors that don't show up in AVPlayer.status
  func avItemStatusDidChange(_ status: AVPlayerItem.Status, error: Error?) {
    if status == .failed {
      let effectiveError = error ?? avPlayer.currentItem?.error
      errorHandler.handleError(effectiveError, context: .playback)
    }
  }

  func audioDidStart() {
    // Don't override loading state - MediaLoader manages that transition
    if state == .loading { return }
    transition(.audioFrameDecoded)
  }

  func avItemDidUpdatePlaybackLikelyToKeepUp(_ playbackLikelyToKeepUp: Bool) {
    guard playbackLikelyToKeepUp else { return }

    // KVO callbacks are dispatched to MainActor asynchronously, so a stale callback
    // from a previous AVPlayerItem can arrive after the item was replaced/cleared.
    // Ignore these — there's nothing meaningful to do without a loaded item.
    guard avPlayer.currentItem != nil else { return }

    // Execute any pending seek that arrived after MediaLoader completed
    if loadSeekCoordinator.executeIfPending(on: avPlayer, delegate: self) {
      return
    }

    // Only transition to .ready if no seek is in-flight — otherwise
    // handleSeekCompleted will handle the transition once the seek lands.
    if !loadSeekCoordinator.shouldDeferReadyTransition, state != .playing {
      logger.debug("avItemDidUpdatePlaybackLikelyToKeepUp → .ready")
      transition(.bufferingSufficient)
    }
  }
}
