package dev.fluvie.mobile_encoder

/** Validate channel values before narrowing integers or allocating pixel buffers. */
internal data class FrameExtractionRequest(
  val path: String,
  val indices: List<Int>,
  val width: Int,
  val height: Int,
) {
  companion object {
    private const val LIMIT = 256 * 1024 * 1024

    fun from(arguments: Any?): FrameExtractionRequest? {
      val map = arguments as? Map<*, *> ?: return null
      val path = map["path"] as? String ?: return null
      if (path.isEmpty()) return null
      fun integer(value: Any?): Int? = when (value) {
        is Int -> value
        is Long -> if (value in 0L..Int.MAX_VALUE.toLong()) value.toInt() else null
        else -> null
      }
      val width = integer(map["width"]) ?: return null
      val height = integer(map["height"]) ?: return null
      if (width <= 0 || height <= 0 || width > LIMIT / 4 || height > LIMIT / (width * 4)) return null
      val frameBytes = width * height * 4
      val values = map["indices"] as? List<*> ?: return null
      if (values.size > LIMIT / frameBytes) return null
      val indices = ArrayList<Int>(values.size)
      for (value in values) {
        val index = integer(value) ?: return null
        if (index < 0) return null
        indices.add(index)
      }
      return FrameExtractionRequest(path, indices, width, height)
    }
  }
}
