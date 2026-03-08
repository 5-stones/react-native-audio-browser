@preconcurrency import AVFoundation
import NitroModules

// MARK: - Queue Methods

extension TrackPlayer {
  func replace(_ index: Int, _ track: Track) {
    queue.replace(index, track)
  }

  func setQueue(_ newTracks: [Track], initialIndex: Int = 0, playWhenReady: Bool? = nil, sourcePath: String? = nil) {
    guard !newTracks.isEmpty else {
      clear()
      return
    }
    handlePlayWhenReady(playWhenReady) {
      // setQueue always returns true (current track always changes)
      queue.setQueue(newTracks, initialIndex: initialIndex, sourcePath: sourcePath)
      handleCurrentTrackChanged()
    }
  }

  func add(_ tracks: [Track], initialIndex: Int? = nil, playWhenReady: Bool? = nil) {
    handlePlayWhenReady(playWhenReady) {
      let changed = queue.add(tracks, initialIndex: initialIndex ?? 0)
      if changed { handleCurrentTrackChanged() }
    }
  }

  func add(_ tracks: [Track], at index: Int) throws {
    let changed = try queue.addAt(tracks, at: index)
    if changed { handleCurrentTrackChanged() }
  }

  func next() {
    let result = queue.next()
    switch result {
    case .trackChanged:    handleCurrentTrackChanged()
    case .sameTrackReplay: if playWhenReady { replay() }
    case .noChange:        break
    }
  }

  func previous() {
    let result = queue.previous()
    switch result {
    case .trackChanged:    handleCurrentTrackChanged()
    case .sameTrackReplay: if playWhenReady { replay() }
    case .noChange:        break
    }
  }

  func remove(_ index: Int) throws {
    let changed = try queue.remove(index)
    if changed { handleCurrentTrackChanged() }
  }

  func skipTo(_ index: Int, playWhenReady: Bool? = nil) throws {
    try handlePlayWhenReady(playWhenReady) {
      if index == queue.currentIndex {
        seekTo(0)
      } else {
        // skipTo always returns .trackChanged (same-index is handled above)
        try queue.skipTo(index)
        handleCurrentTrackChanged()
      }
    }
  }

  func move(fromIndex: Int, toIndex: Int) throws {
    let changed = try queue.move(fromIndex: fromIndex, toIndex: toIndex)
    if changed { handleCurrentTrackChanged() }
  }

  func removeUpcomingTracks() {
    queue.removeUpcomingTracks()
  }

  func replay() {
    seekTo(0) { [weak self] succeeded in
      if succeeded { self?.play() }
    }
  }
}

// MARK: - Track Loading

extension TrackPlayer {
  func handleTrackDidPlayToEndTime() {
    // Check if sleep timer should trigger on track end
    sleepTimerManager.onTrackPlayedToEnd()

    if repeatMode == .track {
      replay()
    } else if repeatMode == .queue || !isLastInPlaybackOrder {
      next()
    } else {
      transition(.trackEndedNaturally)
    }
  }

  func handleCurrentTrackChanged() {
    // Reset end-of-track sleep timer when track changes
    sleepTimerManager.onTrackChanged()

    mediaLoader.cancelAll()
    loadSeekCoordinator.reset()

    // Cancel any pending retry and reset count when track changes
    errorHandler.resetRetry()

    // Clear directly rather than via transition() — the code below immediately
    // follows with transition(.trackLoading) which handles the .error → .loading
    // transition and its side effects.
    if playbackError != nil {
      playbackError = nil
    }

    let lastPosition = currentTime
    let shouldContinuePlayback = playWhenReady
    if let currentTrack {
      // Cancel in-flight loading from previous track and clear old item
      // to prevent stale audio during async URL resolution.
      stopObservingAVPlayerItem()
      pausePlayback()
      avPlayer.replaceCurrentItem(with: nil)

      // Set loading state before playWhenReady so the setter's guard
      // prevents a no-op startPlayback() on the now-nil item.
      transition(.trackLoading)

      // Ensure playWhenReady is set before loading to preserve playback state
      playWhenReady = shouldContinuePlayback

      // Reset playback values without updating, because that will happen in
      // the nowPlayingUpdater.loadMetaValues call straight after:
      nowPlayingInfoController.setWithoutUpdate(keyValues: [
        MediaItemProperty.duration(nil),
        NowPlayingInfoProperty.playbackRate(nil),
        NowPlayingInfoProperty.elapsedPlaybackTime(nil),
      ])
      nowPlayingUpdater.loadMetaValues(for: currentTrack, rate: rate)

      // Validate source URL before handing off to MediaLoader
      guard let src = currentTrack.src else {
        logger.error("Failed to load track - no src")
        logger.error("  track.title: \(currentTrack.title)")
        logger.error("  track.url: \(currentTrack.url ?? "nil")")
        clearCurrentAVItem()
        transition(.errorOccurred(.invalidSourceUrl("nil")))
        return
      }

      logger.debug("Loading track: \(currentTrack.title)")
      logger.debug("  track.url: \(currentTrack.url ?? "nil")")
      logger.debug("  track.src: \(src)")

      mediaLoader.resolveAndLoad(src: src)
    } else {
      unloadAVPlayer()
      nowPlayingInfoController.clear()
    }

    let eventData = PlaybackActiveTrackChangedEvent(
      lastIndex: lastIndex == -1 ? nil : Double(lastIndex),
      lastTrack: lastTrack,
      lastPosition: lastPosition,
      index: currentIndex == -1 ? nil : Double(currentIndex),
      track: currentTrack,
    )
    callbacks?.playerDidChangeActiveTrack(eventData)
    lastTrack = currentTrack
    lastIndex = currentIndex
  }
}

// MARK: - QueueManagerDelegate

extension TrackPlayer: QueueManagerDelegate {
  func queueDidChangeTracks(_ tracks: [Track]) {
    callbacks?.playerDidChangeQueue(tracks)
  }
}

// MARK: - SeekCompletionHandler

extension TrackPlayer: SeekCompletionHandler {}

// MARK: - TrackSelectionPlayer

extension TrackPlayer: TrackSelectionPlayer {}

// MARK: - MediaLoaderDelegate

extension TrackPlayer: MediaLoaderDelegate {
  func mediaLoaderDidPrepareItem(_ item: AVPlayerItem) {
    nowPlayingInfoController.prepareItem(item)
    avPlayer.replaceCurrentItem(with: item)
    startObservingAVPlayerItem(item)
    if playWhenReady { startPlayback() }

    if !loadSeekCoordinator.executeIfPending(on: avPlayer, delegate: self) {
      if item.isPlaybackLikelyToKeepUp {
        avItemDidUpdatePlaybackLikelyToKeepUp(true)
      }
    }
  }

  func mediaLoaderDidFailWithRetryableError(_ error: Error) {
    errorHandler.handleError(error, context: .mediaLoad)
  }

  func mediaLoaderDidFailWithUnplayableTrack() {
    transition(.errorOccurred(.trackWasUnplayable))
  }

  func mediaLoaderDidFailWithError(_ error: TrackPlayerError.PlaybackError) {
    transition(.errorOccurred(error))
  }

  func mediaLoaderDidReceiveCommonMetadata(_ items: [AVMetadataItem]) {
    callbacks?.playerDidReceiveCommonMetadata(items)
  }

  func mediaLoaderDidReceiveChapterMetadata(_ groups: [AVTimedMetadataGroup]) {
    callbacks?.playerDidReceiveChapterMetadata(groups)
  }

  func mediaLoaderDidReceiveTimedMetadata(_ groups: [AVTimedMetadataGroup]) {
    callbacks?.playerDidReceiveTimedMetadata(groups)
  }
}
