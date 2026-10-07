package dev.fluvie.mobile_encoder

import android.graphics.Bitmap
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build

/**
 * Reads a video clip's facts and decodes specific source frames to RGBA on the
 * device — the no-ffmpeg counterpart to fluvie's `VideoProbeService` /
 * `FrameExtractionService`, backed by [MediaMetadataRetriever].
 *
 * `getFrameAtIndex` (API 28+) returns frames already in display orientation, so
 * [probe] reports display dimensions (raw dimensions swapped for a 90/270°
 * rotation) and [extractFrames] scales each frame to the requested size.
 */
object VideoFrameReader {
  /** Probes [path] for `width`, `height`, `frameCount`, `durationMs`, `codec`. */
  fun probe(path: String): Map<String, Any?> {
    requireFrameApi()
    val retriever = MediaMetadataRetriever()
    try {
      retriever.setDataSource(path)
      fun meta(key: Int) = retriever.extractMetadata(key)
      val rawWidth = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
      val rawHeight = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
      val rotation = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
      val durationMs = meta(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
      var mime = "video/avc"
      var fpsHint: Double? = null
      var videoDurationUs = 0L
      var presentationSpanUs: Long? = null
      val presentationTimesUs = ArrayList<Long>()
      var frameCount = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT)?.toIntOrNull() ?: 0
      // Container duration includes any AAC tail. Preserve the video track's
      // declared clock rather than deriving a slower fps from that duration.
      val extractor = MediaExtractor()
      try {
        extractor.setDataSource(path)
        for (index in 0 until extractor.trackCount) {
          val format = extractor.getTrackFormat(index)
          val trackMime = format.getString(MediaFormat.KEY_MIME) ?: continue
          if (!trackMime.startsWith("video/")) continue
          mime = trackMime
          if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
            fpsHint = format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
          }
          if (format.containsKey(MediaFormat.KEY_DURATION)) videoDurationUs = format.getLong(MediaFormat.KEY_DURATION)
          // KEY_FRAME_RATE is an integer, while KEY_DURATION may include a
          // decoder lead-in even for a video-only B-frame track. Read the
          // presentation span without decoding or retaining sample buffers.
          extractor.selectTrack(index)
          var samples = 0
          var firstTime = Long.MAX_VALUE
          var lastTime = Long.MIN_VALUE
          while (extractor.sampleTrackIndex >= 0) {
            val time = extractor.sampleTime
            firstTime = minOf(firstTime, time)
            lastTime = maxOf(lastTime, time)
            check(samples < Int.MAX_VALUE) { "The clip contains too many frames." }
            check(samples < 1_000_000) { "Clip timestamp indexing is limited to one million frames." }
            presentationTimesUs.add(time)
            samples++
            if (!extractor.advance()) break
          }
          if (samples > 0) {
            frameCount = samples
            presentationSpanUs = lastTime - firstTime
          }
          break
        }
      } finally {
        extractor.release()
      }
      // Frames come back display-oriented, so report display (rotated) dimensions.
      val rotated = rotation == 90 || rotation == 270
      val width = if (rotated) rawHeight else rawWidth
      val height = if (rotated) rawWidth else rawHeight
      val durationUs = if (videoDurationUs > 0) videoDurationUs else durationMs * 1000
      val fps = VideoTrackTiming.fps(frameCount, durationUs, fpsHint, presentationSpanUs)
      presentationTimesUs.sort()
      val originUs = presentationTimesUs.firstOrNull() ?: 0L
      return mapOf(
        "width" to width,
        "height" to height,
        "frameCount" to frameCount,
        "durationMs" to (durationUs / 1000),
        "durationUs" to durationUs,
        "codec" to codecName(mime),
        "fps" to fps,
        "timeline" to mapOf("schemaVersion" to 1,
          "presentationTimesUs" to presentationTimesUs.map { it - originUs },
          "durationUs" to durationUs),
        "hasAudio" to (meta(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes"),
      )
    } finally {
      retriever.release()
    }
  }

  /**
   * Decodes each source frame in [indices] of [path] to RGBA8888, scaled to
   * [width] x [height], and returns them concatenated row-major in request order
   * (one `width * height * 4` block per index).
   */
  fun extractFrames(path: String, indices: List<Int>, width: Int, height: Int): ByteArray {
    requireFrameApi()
    if (indices.isEmpty()) return ByteArray(0)
    val retriever = MediaMetadataRetriever()
    try {
      retriever.setDataSource(path)
      val frameBytes = width * height * 4
      val out = ByteArray(indices.size * frameBytes)
      val pixels = IntArray(width * height)
      var offset = 0
      for (index in indices) {
        var bitmap = retriever.getFrameAtIndex(index)
          ?: throw IllegalStateException("decoder returned no frame at index $index")
        if (bitmap.width != width || bitmap.height != height) {
          val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
          if (scaled !== bitmap) bitmap.recycle()
          bitmap = scaled
        }
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        for (pixel in pixels) {
          // ARGB int -> R, G, B, A bytes (matches fluvie's RawFrame layout).
          out[offset++] = ((pixel shr 16) and 0xFF).toByte()
          out[offset++] = ((pixel shr 8) and 0xFF).toByte()
          out[offset++] = (pixel and 0xFF).toByte()
          out[offset++] = ((pixel shr 24) and 0xFF).toByte()
        }
        bitmap.recycle()
      }
      return out
    } finally {
      retriever.release()
    }
  }

  private fun requireFrameApi() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
      throw IllegalStateException(
        "On-device video clip rendering needs Android 9 (API 28) or newer.",
      )
    }
  }

  private fun codecName(mime: String): String =
    if (mime.contains("hevc") || mime.contains("h265")) "hevc" else "h264"
}
