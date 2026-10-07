package dev.fluvie.mobile_encoder

/** Measures the chosen codec pair's priming with two opposite isolated impulses.
 * This is independent of the user's signal, silence, or musical periodicity.
 */
internal object AacDelayCalibration {
  const val PROBE_FRAMES = 24576
  private const val FIRST = 4096
  private const val SECOND = 12288
  private const val MAX_DELAY = 8192

  fun signal(channels: Int): FloatArray = FloatArray(PROBE_FRAMES * channels).also { samples ->
    for (channel in 0 until channels) {
      samples[FIRST * channels + channel] = 0.9f
      samples[SECOND * channels + channel] = -0.7f
    }
  }

  fun measure(samples: ShortArray, channels: Int): Int {
    require(channels > 0 && samples.size / channels > SECOND + MAX_DELAY) {
      "AAC calibration returned insufficient PCM"
    }
    var best = Double.NEGATIVE_INFINITY
    var delay = 0
    for (candidate in 0..MAX_DELAY) {
      val score = samples[(FIRST + candidate) * channels] * 0.9 -
        samples[(SECOND + candidate) * channels] * 0.7
      if (score > best) { best = score; delay = candidate }
    }
    require(best > 1000 && delay < MAX_DELAY) { "Could not establish AAC encoder priming" }
    return delay
  }
}
