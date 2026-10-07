package dev.fluvie.mobile_encoder

import org.junit.Assert.*
import org.junit.Test

class PcmTrackMixerTest {
  @Test fun aSeekWindowEqualsTheSameSliceOfTheCompleteAuthoredMix() {
    val spec = AudioTrackSpec("unused", 100, 0.5f, 0.1, 1.8, 0.6, 0.4, 1.3,
      true, 1.0, 1.9, listOf(0.0 to 0.2f, 1.0 to 1f), 2.0, listOf(0.0, 0.1, 0.4, 0.9, 1.6))
    val pcm = DecodedPcm(ShortArray(20) { ((it - 10) * 2000).toShort() }, 10, 1)
    val full = FloatArray(40)
    val window = FloatArray(20)
    PcmTrackMixer.mix(spec, pcm, full, 20, 10, 2, 0.8f, 0.0)
    PcmTrackMixer.mix(spec, pcm, window, 10, 10, 2, 0.8f, 0.7)
    assertArrayEquals(full.copyOfRange(14, 34), window, 0f)
    assertTrue(window.any { it != 0f })
  }
}
