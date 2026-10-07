package dev.fluvie.mobile_encoder

import kotlin.math.abs

/** Preserve fractional cadence from the video track, never an AAC/container tail. */
internal object VideoTrackTiming {
  fun fps(frameCount: Int, durationUs: Long, hint: Double?, presentationSpanUs: Long? = null): Double? {
    if (frameCount > 1 && presentationSpanUs != null && presentationSpanUs > 0) {
      val measured = (frameCount - 1) * 1_000_000.0 / presentationSpanUs
      // Microsecond PTS quantization slightly perturbs even integer rates.
      // Snap only that rounding noise, never NTSC cadence, to the format hint.
      return if (hint != null && abs(measured - hint) < 0.0001) hint else measured
    }
    return when {
      hint != null && hint > 0 && hint.isFinite() -> hint
      frameCount > 0 && durationUs > 0 -> frameCount * 1_000_000.0 / durationUs
      else -> null
    }
  }
}
