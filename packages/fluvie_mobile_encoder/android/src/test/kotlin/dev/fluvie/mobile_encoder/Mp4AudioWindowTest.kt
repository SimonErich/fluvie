package dev.fluvie.mobile_encoder

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class Mp4AudioWindowTest {
  private fun box(type: String, vararg children: ByteArray) = Mp4AudioWindow.box(type, children.toList())
  private fun timeHeader(size: Int, scale: Int) = ByteArray(size).also {
    ByteBuffer.wrap(it).putInt(12, scale).putInt(16, scale * 4)
  }
  private fun track(type: String): ByteArray {
    val handler = ByteArray(12).also { type.toByteArray().copyInto(it, 8) }
    val tkhd = ByteArray(84).also { ByteBuffer.wrap(it).putInt(20, 4000) }
    return box("trak", box("tkhd", tkhd), box("mdia", box("mdhd", timeHeader(24, 44100)),
      box("hdlr", handler), box("minf", byteArrayOf(1, 2, 3, 4))))
  }
  private fun movie() = box("moov", box("mvhd", timeHeader(100, 1000)), track("vide"), track("soun"))

  @Test fun `appends edited movie while preserving every media offset`() {
    val file = File.createTempFile("fluvie_mp4_", ".mp4")
    try {
      val prefix = box("ftyp", "isom0000".toByteArray())
      val moov = movie()
      val media = box("mdat", ByteArray(128) { it.toByte() })
      val original = prefix + moov + media
      file.writeBytes(original)
      Mp4AudioWindow.apply(file.path, 2112, 44100, 3.0)
      val result = file.readBytes()
      assertArrayEquals(media, result.copyOfRange(prefix.size + moov.size, original.size))
      assertEquals("free", String(result, prefix.size + 4, 4))
      val appended = result.copyOfRange(original.size, result.size)
      val children = Mp4AudioWindow.boxes(appended, 8, appended.size)
      val mvhd = children.single { it.type == "mvhd" }
      assertEquals(3000, ByteBuffer.wrap(appended).getInt(mvhd.offset + mvhd.header + 16))
      val tracks = children.filter { it.type == "trak" }
      assertArrayEquals(track("vide"), appended.copyOfRange(tracks[0].offset, tracks[0].offset + tracks[0].size))
      val audio = tracks[1]
      val sub = Mp4AudioWindow.boxes(appended, audio.offset + audio.header, audio.offset + audio.size)
      val tkhd = sub.single { it.type == "tkhd" }
      assertEquals(3000, ByteBuffer.wrap(appended).getInt(tkhd.offset + tkhd.header + 20))
      val edit = sub.single { it.type == "edts" }
      val elst = edit.offset + edit.header + 8
      assertEquals(1, appended[elst].toInt())
      assertEquals(3000L, ByteBuffer.wrap(appended).getLong(elst + 8))
      assertEquals(2112L, ByteBuffer.wrap(appended).getLong(elst + 16))
      assertEquals(0x10000, ByteBuffer.wrap(appended).getInt(elst + 24))
    } finally { file.delete() }
  }

  @Test fun `supports large box headers without truncating their children`() {
    val normal = movie()
    val large = ByteBuffer.allocate(normal.size + 8).putInt(1).put("moov".toByteArray())
      .putLong((normal.size + 8).toLong()).put(normal, 8, normal.size - 8).array()
    assertArrayEquals(Mp4AudioWindow.rewrite(normal, 1024, 44100, 3.0),
      Mp4AudioWindow.rewrite(large, 1024, 44100, 3.0))
  }

  @Test fun `rejects truncated and overflowing child lengths`() {
    for (bytes in listOf(ByteArray(7), ByteBuffer.allocate(8).putInt(Int.MAX_VALUE).putInt(0).array(),
      ByteBuffer.allocate(16).putInt(1).putInt(0).putLong(Long.MAX_VALUE).array(),
      ByteBuffer.allocate(8).putInt(4).putInt(0).array())) {
      assertThrows(IllegalArgumentException::class.java) { Mp4AudioWindow.boxes(bytes, 0, bytes.size) }
    }
  }

  @Test fun `rejects oversized metadata before allocating it`() {
    val file = File.createTempFile("fluvie_large_", ".mp4")
    try {
      RandomAccessFile(file, "rw").use {
        it.setLength(70L * 1024 * 1024)
        it.writeInt(70 * 1024 * 1024)
        it.write("moov".toByteArray())
      }
      assertThrows(IllegalArgumentException::class.java) { Mp4AudioWindow.apply(file.path, 0, 44100, 3.0) }
      assertEquals(70L * 1024 * 1024, file.length())
    } finally { file.delete() }
  }

  @Test fun `rejects open ended media without mutating the file`() {
    val file = File.createTempFile("fluvie_open_", ".mp4")
    try {
      val original = movie() + ByteBuffer.allocate(16).putInt(0).put("mdat".toByteArray()).array()
      file.writeBytes(original)
      assertThrows(IllegalArgumentException::class.java) { Mp4AudioWindow.apply(file.path, 0, 44100, 3.0) }
      assertArrayEquals(original, file.readBytes())
    } finally { file.delete() }
  }
}
