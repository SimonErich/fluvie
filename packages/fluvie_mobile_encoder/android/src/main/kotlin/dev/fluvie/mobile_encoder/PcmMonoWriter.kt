package dev.fluvie.mobile_encoder

import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Writes precisely the decoded buffer slice as bounded, mono float32 LE PCM. */
internal object PcmMonoWriter {
  fun write(
    buffer: ByteBuffer, offset: Int, size: Int, channels: Int,
    floatPcm: Boolean, output: OutputStream, remaining: Int,
  ): Int {
    val bytesPerSample = if (floatPcm) 4 else 2
    require(channels > 0 && size >= 0 && offset >= 0 &&
      offset.toLong() + size <= buffer.capacity()) { "Invalid decoded PCM buffer slice" }
    require(size % (bytesPerSample * channels) == 0) { "Incomplete decoded PCM frame" }
    val frames = size / bytesPerSample / channels
    require(frames <= remaining) { "Audio exceeds the configured PCM analysis sample limit" }
    val input = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
    input.position(offset)
    input.limit(offset + size)
    val mono = ByteBuffer.allocate(frames * 4).order(ByteOrder.LITTLE_ENDIAN)
    repeat(frames) {
      var sum = 0.0
      repeat(channels) {
        val value = if (floatPcm) input.float else input.short.toFloat() / 32768
        require(value.isFinite()) { "Nonfinite decoded PCM sample" }
        sum += value
      }
      mono.putFloat((sum / channels).coerceIn(-1.0, 1.0).toFloat())
    }
    output.write(mono.array())
    return frames
  }
}
