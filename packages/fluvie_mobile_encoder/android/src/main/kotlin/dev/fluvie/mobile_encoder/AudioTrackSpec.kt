package dev.fluvie.mobile_encoder

/** One audio track to mix, as sent over the channel. */
data class AudioTrackSpec(
  val path: String,
  val delayMs: Int,
  val volume: Float,
  val trimStartSeconds: Double?,
  val trimEndSeconds: Double?,
  val fadeInSeconds: Double?,
  val fadeOutSeconds: Double?,
  val fadeOutStartSeconds: Double,
  val loop: Boolean,
  val tempo: Double,
  val endSeconds: Double?,
  val volumeEnvelope: List<Pair<Double, Float>>,
  val timeMapFps: Double,
  val sourceTimeMap: List<Double>,
) {
  companion object {
    fun from(map: Map<*, *>): AudioTrackSpec = AudioTrackSpec(
      path = map["path"] as String,
      delayMs = (map["delayMs"] as Number).toInt(),
      volume = (map["volume"] as Number).toFloat(),
      trimStartSeconds = (map["trimStartSeconds"] as Number?)?.toDouble(),
      trimEndSeconds = (map["trimEndSeconds"] as Number?)?.toDouble(),
      fadeInSeconds = (map["fadeInSeconds"] as Number?)?.toDouble(),
      fadeOutSeconds = (map["fadeOutSeconds"] as Number?)?.toDouble(),
      fadeOutStartSeconds = (map["fadeOutStartSeconds"] as Number?)?.toDouble() ?: 0.0,
      loop = map["loop"] as? Boolean ?: false,
      tempo = (map["tempo"] as? Number)?.toDouble() ?: 1.0,
      endSeconds = (map["endSeconds"] as? Number)?.toDouble(),
      timeMapFps = ((map["timeMap"] as? Map<*, *>)?.get("fps") as? Number)?.toDouble() ?: 0.0,
      sourceTimeMap = (((map["timeMap"] as? Map<*, *>)?.get("sourceSeconds")) as? List<*>)?.map { (it as Number).toDouble() } ?: emptyList(),
      volumeEnvelope = (map["volumeEnvelope"] as? List<*>)?.mapNotNull { raw ->
        val point = raw as? Map<*, *> ?: return@mapNotNull null
        val seconds = (point["seconds"] as? Number)?.toDouble() ?: return@mapNotNull null
        val value = (point["value"] as? Number)?.toFloat() ?: return@mapNotNull null
        seconds to value
      } ?: emptyList(),
    )
  }
}
