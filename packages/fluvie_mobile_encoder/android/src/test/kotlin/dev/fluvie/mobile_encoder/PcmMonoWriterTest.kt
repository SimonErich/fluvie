package dev.fluvie.mobile_encoder

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.*
import org.junit.Test

class PcmMonoWriterTest {
  @Test fun respectsBufferSliceAndDownmixesStereo() {
    val buffer = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN)
    buffer.putShort(123).putShort(32767).putShort(-32768).putShort(16384).putShort(16384).putShort(456)
    val output = ByteArrayOutputStream()
    assertEquals(2, PcmMonoWriter.write(buffer, 2, 8, 2, false, output, 2))
    val result = ByteBuffer.wrap(output.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
    assertEquals(-1f / 65536, result.float, 0.00001f)
    assertEquals(0.5f, result.float, 0f)
  }
  @Test fun floatPcmIsNormalizedAndBoundedBeforeWriting() {
    val buffer = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putFloat(2f).putFloat(-0.5f)
    val output = ByteArrayOutputStream()
    try { PcmMonoWriter.write(buffer, 0, 8, 1, true, output, 1); fail("unbounded samples accepted") }
    catch (_: IllegalArgumentException) {}
    assertEquals(0, output.size())
    assertEquals(2, PcmMonoWriter.write(buffer, 0, 8, 1, true, output, 2))
    val result = ByteBuffer.wrap(output.toByteArray()).order(ByteOrder.LITTLE_ENDIAN)
    assertEquals(1f, result.float, 0f)
    assertEquals(-0.5f, result.float, 0f)
  }
}
