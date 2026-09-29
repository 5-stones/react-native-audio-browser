package com.audiobrowser.player

import okhttp3.HttpUrl
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response

/**
 * Drops the caller's headers once a redirect leaves the origin.
 *
 * OkHttp does this for `Authorization` alone — RetryAndFollowUpInterceptor.buildRedirectRequest is
 * a single `removeHeader("Authorization")` — so every other configured header, an `X-Api-Key` say,
 * still reaches whatever host the first one named. iOS forwards none across a hop and web clears
 * them too; this brings Android in line.
 *
 * Installed as a **network** interceptor, which runs once per hop. `chain.call().request()` is the
 * call's original request, so the comparison is always against the URL the credential was addressed
 * to rather than the hop before.
 *
 * Scoped to the redirect hop, and only that. An HLS segment or key fetch is its own Call, already
 * addressed to the absolute CDN URL, and [TransformingDataSource] deliberately re-applies the
 * config's headers to it — authenticated segments are a supported shape, and web does the same
 * through Shaka's request filter. So this closes the leak of handing a credential to a host the
 * caller never named; it is not a rule that the credential stays on one origin.
 */
internal object CrossOriginHeaderStripper : Interceptor {

  /**
   * Headers that describe the transport rather than the caller. OkHttp and media3 set these per hop
   * — `Range` carries the seek, `Host` and `Connection` are the connection's own — so the request
   * breaks without them. Everything else on a media request came from the media config, and is the
   * caller's to send only to the host it addressed.
   *
   * `Icy-MetaData` is media3's, not the caller's: `ProgressiveMediaPeriod` asks for Shoutcast
   * metadata through `ICY_METADATA_HEADERS` on the DataSpec — the same channel
   * [TransformingDataSource] puts the config's headers on, so nothing downstream can tell them
   * apart. Dropping it on a hop costs the station's `icy-metaint`, so `IcyDataSource` is never
   * installed and `onMetadata` stops firing: live "now playing" disappears on exactly the
   * redirecting streams this interceptor exists for, and the interleaved metadata bytes stay in the
   * audio as audible chirping. It is a request for a response format, never a credential.
   */
  private val TRANSPORT_HEADERS =
    setOf(
      "accept",
      "accept-encoding",
      "connection",
      "content-length",
      "host",
      "icy-metadata",
      "range",
      "transfer-encoding",
      "user-agent",
    )

  override fun intercept(chain: Interceptor.Chain): Response {
    val request = chain.request()
    val addressed = chain.call().request().url
    return chain.proceed(
      if (sameOrigin(addressed, request.url)) request else stripCallerHeaders(request)
    )
  }

  /** Scheme, host and port — the same origin test `followMediaRedirect` applies on web. */
  internal fun sameOrigin(a: HttpUrl, b: HttpUrl): Boolean =
    a.scheme == b.scheme && a.host == b.host && a.port == b.port

  /** The request with every caller-supplied header removed. */
  internal fun stripCallerHeaders(request: Request): Request =
    request
      .newBuilder()
      .apply {
        request.headers.names().forEach { name ->
          if (name.lowercase() !in TRANSPORT_HEADERS) removeHeader(name)
        }
      }
      .build()
}
