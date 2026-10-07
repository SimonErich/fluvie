package dev.fluvie.mobile_encoder

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Adds a sample-accurate audio edit without moving a single encoded chunk.
 *
 * Android MediaMuxer does not write encoder-delay/padding keys as gapless edits.
 * Rewrite only moov: append the replacement and turn the original into free.
 * Call this on the owned staging file, before atomically publishing the MP4.
 */
internal object Mp4AudioWindow {
  private const val MAX_MOOV_BYTES = 64 * 1024 * 1024
  internal data class Box(val offset: Int, val size: Int, val header: Int, val type: String)

  fun apply(path: String, delaySamples: Int, sampleRate: Int, durationSeconds: Double) {
    require(delaySamples >= 0 && sampleRate > 0 && durationSeconds > 0 && durationSeconds.isFinite())
    RandomAccessFile(path, "rw").use { file ->
      val length = file.length()
      var offset = 0L
      var originalOffset = -1L
      var replacement: ByteArray? = null
      while (offset < length) {
        require(length - offset >= 8) { "Truncated MP4 box header" }
        file.seek(offset)
        val shortSize = file.readInt().toLong() and 0xffffffffL
        val typeBytes = ByteArray(4).also { file.readFully(it) }
        val type = String(typeBytes, Charsets.US_ASCII)
        val header = if (shortSize == 1L) 16 else 8
        require(length - offset >= header) { "Truncated large MP4 box header" }
        val size = when (shortSize) {
          0L -> length - offset
          1L -> file.readLong()
          else -> shortSize
        }
        require(size >= header && size <= length - offset) { "Invalid MP4 box length" }
        if (type == "moov") {
          require(replacement == null) { "Multiple MP4 movie boxes" }
          require(size <= MAX_MOOV_BYTES) { "MP4 movie metadata exceeds 64 MiB" }
          file.seek(offset)
          val bytes = ByteArray(size.toInt()).also { file.readFully(it) }
          replacement = rewrite(bytes, delaySamples, sampleRate, durationSeconds)
          originalOffset = offset
        }
        // Appending after an open-ended mdat would hide the replacement moov.
        require(shortSize != 0L) { "Open-ended MP4 boxes cannot be edited safely" }
        offset += size
      }
      val movie = requireNotNull(replacement) { "MP4 has no movie box" }
      try {
        file.seek(length)
        file.write(movie)
        file.fd.sync()
        file.seek(originalOffset + 4)
        file.write("free".toByteArray(Charsets.US_ASCII))
        file.fd.sync()
      } catch (error: Exception) {
        // Restore the previous valid metadata if storage fails during staging.
        file.setLength(length)
        file.seek(originalOffset + 4)
        file.write("moov".toByteArray(Charsets.US_ASCII))
        throw error
      }
    }
  }

  internal fun boxes(bytes: ByteArray, start: Int, end: Int): List<Box> {
    require(start >= 0 && end >= start && end <= bytes.size)
    val result = ArrayList<Box>()
    var offset = start
    while (offset < end) {
      require(end - offset >= 8) { "Truncated child MP4 box" }
      val shortSize = uint(bytes, offset)
      val header = if (shortSize == 1L) 16 else 8
      require(end - offset >= header) { "Truncated large child MP4 box" }
      val size = when (shortSize) {
        0L -> (end - offset).toLong()
        1L -> buffer(bytes).getLong(offset + 8)
        else -> shortSize
      }
      require(size >= header && size <= end - offset) { "Invalid child MP4 box length" }
      result.add(Box(offset, size.toInt(), header, String(bytes, offset + 4, 4, Charsets.US_ASCII)))
      offset += size.toInt()
    }
    return result
  }

  internal fun rewrite(bytes: ByteArray, delaySamples: Int, sampleRate: Int, durationSeconds: Double): ByteArray {
    val root = boxes(bytes, 0, bytes.size).single()
    require(root.type == "moov")
    val children = boxes(bytes, root.header, bytes.size)
    val mvhd = children.single { it.type == "mvhd" }
    val movieScale = timeScale(bytes, mvhd)
    val duration = Math.round(durationSeconds * movieScale)
    var audioCount = 0
    val rewritten = children.map { child ->
      when (child.type) {
        "mvhd" -> withDuration(bytes, child, duration, false)
        "trak" -> {
          val trackChildren = boxes(bytes, child.offset + child.header, child.offset + child.size)
          val mdia = trackChildren.single { it.type == "mdia" }
          val mediaChildren = boxes(bytes, mdia.offset + mdia.header, mdia.offset + mdia.size)
          val handler = mediaChildren.single { it.type == "hdlr" }
          require(handler.size >= handler.header + 12) { "Truncated handler" }
          val type = String(bytes, handler.offset + handler.header + 8, 4, Charsets.US_ASCII)
          if (type != "soun") raw(bytes, child) else {
            audioCount++
            val mediaScale = timeScale(bytes, mediaChildren.single { it.type == "mdhd" })
            val mediaTime = Math.round(delaySamples.toDouble() * mediaScale / sampleRate)
            val content = trackChildren.filter { it.type != "edts" }.map {
              if (it.type == "tkhd") withDuration(bytes, it, duration, true) else raw(bytes, it)
            } + edit(duration, mediaTime)
            box("trak", content)
          }
        }
        else -> raw(bytes, child)
      }
    }
    require(audioCount == 1) { "Expected one mixed MP4 audio track" }
    return box("moov", rewritten)
  }

  private fun timeScale(bytes: ByteArray, box: Box): Long {
    val base = box.offset + box.header
    require(box.size > box.header) { "Truncated MP4 time header" }
    val version = bytes[base].toInt() and 0xff
    require(version == 0 || version == 1) { "Unsupported MP4 time header version" }
    val relative = if (version == 1) 20 else 12
    require(box.size >= box.header + relative + 4) { "Truncated MP4 time header" }
    return uint(bytes, base + relative).also { require(it > 0) { "Zero MP4 time scale" } }
  }

  private fun withDuration(bytes: ByteArray, box: Box, duration: Long, track: Boolean): ByteArray {
    val out = raw(bytes, box)
    require(box.size > box.header) { "Truncated MP4 duration header" }
    val version = out[box.header].toInt() and 0xff
    require(version == 0 || version == 1) { "Unsupported MP4 duration version" }
    val relative = if (track) (if (version == 1) 28 else 20) else (if (version == 1) 24 else 16)
    val offset = box.header + relative
    require(out.size >= offset + (if (version == 1) 8 else 4)) { "Truncated MP4 duration" }
    if (version == 1) buffer(out).putLong(offset, duration) else {
      require(duration in 0..0xffffffffL) { "MP4 version zero duration overflow" }
      buffer(out).putInt(offset, duration.toInt())
    }
    return out
  }

  private fun edit(duration: Long, mediaTime: Long): ByteArray {
    val bytes = ByteArrayOutputStream()
    DataOutputStream(bytes).use {
      it.writeInt(0x01000000) // elst version 1, 64-bit durations and media times
      it.writeInt(1)
      it.writeLong(duration)
      it.writeLong(mediaTime)
      it.writeInt(0x00010000) // rate 1.0
    }
    return box("edts", listOf(box("elst", listOf(bytes.toByteArray()))))
  }

  private fun raw(bytes: ByteArray, box: Box) = bytes.copyOfRange(box.offset, box.offset + box.size)
  private fun uint(bytes: ByteArray, offset: Int) = buffer(bytes).getInt(offset).toLong() and 0xffffffffL
  private fun buffer(bytes: ByteArray) = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN)
  internal fun box(type: String, children: List<ByteArray>): ByteArray {
    val size = 8L + children.sumOf { it.size.toLong() }
    require(size <= MAX_MOOV_BYTES) { "MP4 movie metadata exceeds 64 MiB" }
    val out = ByteArrayOutputStream(size.toInt())
    DataOutputStream(out).use { stream ->
      stream.writeInt(size.toInt())
      stream.write(type.toByteArray(Charsets.US_ASCII))
      children.forEach { stream.write(it) }
    }
    return out.toByteArray()
  }
}
