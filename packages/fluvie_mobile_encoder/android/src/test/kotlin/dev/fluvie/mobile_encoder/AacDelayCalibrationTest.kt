package dev.fluvie.mobile_encoder

import org.junit.Assert.*
import org.junit.Test

class AacDelayCalibrationTest {
  @Test fun `measures different codec delays instead of assuming a platform constant`() {
    for (channels in listOf(1, 2)) for (delay in listOf(0, 576, 1024, 2112, 4096)) {
      val signal = AacDelayCalibration.signal(channels)
      val decoded = ShortArray(signal.size + delay * channels)
      for (i in signal.indices) decoded[i + delay * channels] = (signal[i] * 16000).toInt().toShort()
      assertEquals(delay, AacDelayCalibration.measure(decoded, channels))
    }
  }

  @Test fun `refuses silence or a truncated calibration rather than guessing`() {
    assertThrows(IllegalArgumentException::class.java) {
      AacDelayCalibration.measure(ShortArray(AacDelayCalibration.PROBE_FRAMES * 2), 2)
    }
    assertThrows(IllegalArgumentException::class.java) {
      AacDelayCalibration.measure(ShortArray(8), 2)
    }
  }
}
