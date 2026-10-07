package dev.fluvie.mobile_encoder

import org.junit.Assert.*
import org.junit.Test

class FrameExtractionRequestTest {
  private fun values() = mutableMapOf<String, Any>(
    "path" to "/clip.mp4", "indices" to listOf(5, 0, 5), "width" to 1920, "height" to 1080,
  )

  @Test fun `retains caller order and accepts bounded channel integers`() {
    val request = FrameExtractionRequest.from(values())!!
    assertEquals(listOf(5, 0, 5), request.indices)
    assertEquals(1920, request.width)
    assertEquals(1080, request.height)
    assertEquals(16, FrameExtractionRequest.from(values().apply { put("width", 16L) })!!.width)
    assertTrue(FrameExtractionRequest.from(values().apply { put("indices", emptyList<Int>()) })!!.indices.isEmpty())
  }

  @Test fun `rejects malformed and overflowing allocation requests`() {
    for (width in listOf(0, -1, 1L shl 62, 16.5, Int.MAX_VALUE)) {
      assertNull("width $width", FrameExtractionRequest.from(values().apply { put("width", width) }))
    }
    for (indices in listOf(listOf(-1), listOf(1L shl 62), listOf(0.5), List(100) { 0 })) {
      assertNull("indices $indices", FrameExtractionRequest.from(values().apply { put("indices", indices) }))
    }
    assertNull(FrameExtractionRequest.from(values().apply { put("height", Int.MAX_VALUE) }))
    assertNull(FrameExtractionRequest.from(values().apply { put("path", "") }))
    assertNull(FrameExtractionRequest.from(null))
  }
}
