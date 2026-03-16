package com.audiobrowser.player

import com.margelo.nitro.audiobrowser.PlaybackState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PlaybackProgressUpdateManagerTest {

  @Before
  fun setup() {
    Dispatchers.setMain(UnconfinedTestDispatcher())
  }

  @After
  fun tearDown() {
    Dispatchers.resetMain()
  }

  @Test
  fun `setUpdateInterval before playback does not emit events`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.setUpdateInterval(0.1)

    advanceTimeBy(500)
    assertEquals(0, callCount)
    manager.stop()
  }

  @Test
  fun `setUpdateInterval while running restarts with new interval`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.setUpdateInterval(0.1)
    manager.start()

    advanceTimeBy(350)
    assertTrue("Expected events while running, got $callCount", callCount > 0)

    val countBefore = callCount
    manager.setUpdateInterval(0.2) // different value — should restart
    advanceTimeBy(500)
    assertTrue("Expected more events after interval change", callCount > countBefore)

    manager.stop()
  }

  @Test
  fun `start begins emitting, stop ceases emitting`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.setUpdateInterval(0.1)
    manager.start()

    advanceTimeBy(350)
    assertTrue("Expected events after start", callCount > 0)

    manager.stop()
    val countAfterStop = callCount

    advanceTimeBy(500)
    assertEquals(countAfterStop, callCount)
  }

  @Test
  fun `start without interval does nothing`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.start()

    advanceTimeBy(500)
    assertEquals(0, callCount)
  }

  @Test
  fun `playing state starts timer, paused stops it`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.setUpdateInterval(0.1)
    manager.onPlaybackStateChanged(PlaybackState.PLAYING)

    advanceTimeBy(350)
    assertTrue("Expected events when playing", callCount > 0)

    manager.onPlaybackStateChanged(PlaybackState.PAUSED)
    val countAfterPause = callCount

    advanceTimeBy(500)
    assertEquals(countAfterPause, callCount)
  }

  @Test
  fun `loading and buffering states also start timer`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.setUpdateInterval(0.1)

    manager.onPlaybackStateChanged(PlaybackState.LOADING)
    advanceTimeBy(350)
    assertTrue("Expected events when loading", callCount > 0)

    manager.onPlaybackStateChanged(PlaybackState.STOPPED)
    val afterStop = callCount

    manager.onPlaybackStateChanged(PlaybackState.BUFFERING)
    advanceTimeBy(350)
    assertTrue("Expected events when buffering", callCount > afterStop)

    manager.stop()
  }

  @Test
  fun `setting nil interval stops timer`() = runTest {
    var callCount = 0
    val manager = PlaybackProgressUpdateManager { callCount++ }

    manager.setUpdateInterval(0.1)
    manager.start()

    advanceTimeBy(350)
    assertTrue("Expected events before clearing", callCount > 0)

    manager.setUpdateInterval(null)
    val afterNil = callCount

    advanceTimeBy(500)
    assertEquals(afterNil, callCount)
  }
}
