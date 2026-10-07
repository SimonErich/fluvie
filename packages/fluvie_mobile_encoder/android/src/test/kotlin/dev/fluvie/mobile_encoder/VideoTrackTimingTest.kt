package dev.fluvie.mobile_encoder

import org.junit.Assert.*
import org.junit.Test

class VideoTrackTimingTest {
  @Test fun `retains NTSC cadence instead of an integer frame-rate hint`() {
    // Android reports a lead-in in this B-frame track's duration, and rounds
    // its declared rate to 30. The actual presentation span is authoritative.
    assertEquals(30000.0 / 1001, VideoTrackTiming.fps(12, 433767, 30.0, 367033)!!, 0.0001)
  }
  @Test fun `integer PTS quantization is snapped without losing measured cadence`() {
    assertEquals(24.0, VideoTrackTiming.fps(96, 4087000, 24.0, 3958333)!!, 0.0)
    assertEquals(24.0, VideoTrackTiming.fps(97, 4087000, 30.0, 4000000)!!, 0.0)
  }
  @Test fun `uses hints only when exact video timing is unavailable`() {
    assertEquals(24.0, VideoTrackTiming.fps(96, 4000000, null)!!, 0.0)
    assertEquals(24.0, VideoTrackTiming.fps(0, 4000000, 24.0)!!, 0.0)
    assertNull(VideoTrackTiming.fps(0, 0, Double.NaN))
    assertNull(VideoTrackTiming.fps(0, 0, 0.0))
  }
}
