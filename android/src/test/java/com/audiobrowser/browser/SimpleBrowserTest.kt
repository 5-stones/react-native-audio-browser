package com.audiobrowser.browser

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class SimpleBrowserTest {

  @Test
  fun `basic test without promises`() {
    val browserManager = BrowserManager()
    assertEquals("/", browserManager.getPath())
  }

  @Test
  fun `simple router test`() {
    val router = SimpleRouter()
    val routes = mapOf("/test" to "value")
    val match = router.findBestMatch("/test", routes)
    assertNotNull(match)
    assertEquals("/test", match!!.first)
  }

  @Test
  fun `navigate with empty config throws ContentNotFoundException`() {
    runBlocking {
      val browserManager = BrowserManager()
      browserManager.config = BrowserConfig()
      try {
        browserManager.navigate("/test")
        fail("Expected ContentNotFoundException")
      } catch (_: ContentNotFoundException) {}
    }
  }
}
