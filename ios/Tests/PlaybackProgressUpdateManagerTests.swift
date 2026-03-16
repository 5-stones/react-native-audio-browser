import Testing
@testable import AudioBrowserTestable

@Suite("PlaybackProgressUpdateManager")
@MainActor
struct PlaybackProgressUpdateManagerTests {

  // MARK: - Helpers

  private func makeManager() -> (PlaybackProgressUpdateManager, () -> Int) {
    var callCount = 0
    let manager = PlaybackProgressUpdateManager { callCount += 1 }
    return (manager, { callCount })
  }

  // MARK: - setUpdateInterval should not start timer when not running

  @Test("setUpdateInterval before playback does not emit events")
  func setUpdateIntervalBeforePlaybackDoesNotEmit() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)

    // Give time for a potential (incorrect) timer to fire
    try await Task.sleep(for: .milliseconds(50))

    #expect(getCallCount() == 0)
    manager.stop()
  }

  // MARK: - setUpdateInterval restarts timer when already running

  @Test("setUpdateInterval while running restarts with new interval")
  func setUpdateIntervalWhileRunningRestarts() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)
    manager.start()

    try await Task.sleep(for: .milliseconds(50))
    #expect(getCallCount() > 0)

    let countBeforeChange = getCallCount()
    manager.setUpdateInterval(0.01) // same value — early return
    #expect(getCallCount() >= countBeforeChange)

    manager.setUpdateInterval(0.02) // different value — should restart
    try await Task.sleep(for: .milliseconds(60))
    #expect(getCallCount() > countBeforeChange)

    manager.stop()
  }

  // MARK: - start / stop lifecycle

  @Test("start begins emitting, stop ceases emitting")
  func startAndStop() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)
    manager.start()

    try await Task.sleep(for: .milliseconds(50))
    #expect(getCallCount() > 0)

    manager.stop()
    let countAfterStop = getCallCount()

    try await Task.sleep(for: .milliseconds(50))
    #expect(getCallCount() == countAfterStop)
  }

  @Test("start without interval does nothing")
  func startWithoutInterval() async throws {
    let (manager, getCallCount) = makeManager()

    manager.start()

    try await Task.sleep(for: .milliseconds(50))
    #expect(getCallCount() == 0)
    manager.stop()
  }

  @Test("double start is idempotent")
  func doubleStartIsIdempotent() async throws {
    let (manager, _) = makeManager()

    manager.setUpdateInterval(0.01)
    manager.start()
    manager.start() // should be no-op

    try await Task.sleep(for: .milliseconds(30))
    manager.stop()
  }

  // MARK: - onPlaybackStateChanged

  @Test("playing state starts timer, paused stops it")
  func playbackStateStartsAndStops() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)
    manager.onPlaybackStateChanged(.playing)

    try await Task.sleep(for: .milliseconds(50))
    #expect(getCallCount() > 0)

    manager.onPlaybackStateChanged(.paused)
    let countAfterPause = getCallCount()

    try await Task.sleep(for: .milliseconds(50))
    #expect(getCallCount() == countAfterPause)
  }

  @Test("loading and buffering states also start timer")
  func loadingAndBufferingStartTimer() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)

    manager.onPlaybackStateChanged(.loading)
    try await Task.sleep(for: .milliseconds(30))
    #expect(getCallCount() > 0)

    manager.onPlaybackStateChanged(.stopped)
    let afterStop = getCallCount()

    manager.onPlaybackStateChanged(.buffering)
    try await Task.sleep(for: .milliseconds(30))
    #expect(getCallCount() > afterStop)

    manager.stop()
  }

  @Test("non-active states do not start timer")
  func nonActiveStatesDoNotStart() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)

    for state: PlaybackState in [.none, .ready] {
      manager.onPlaybackStateChanged(state)
      try await Task.sleep(for: .milliseconds(30))
      #expect(getCallCount() == 0)
    }
  }

  // MARK: - Clearing interval

  @Test("setting nil interval stops timer")
  func settingNilIntervalStops() async throws {
    let (manager, getCallCount) = makeManager()

    manager.setUpdateInterval(0.01)
    manager.start()

    try await Task.sleep(for: .milliseconds(30))
    #expect(getCallCount() > 0)

    manager.setUpdateInterval(nil)
    let afterNil = getCallCount()

    try await Task.sleep(for: .milliseconds(30))
    #expect(getCallCount() == afterNil)
  }
}
