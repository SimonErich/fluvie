package dev.fluvie.mobile_encoder

/** Pure authored-time mixing, including exact cropping of a seek window. */
internal object PcmTrackMixer {
  fun mix(spec: AudioTrackSpec, pcm: DecodedPcm, mix: FloatArray, totalFrames: Int,
    sampleRate: Int, channels: Int, masterVolume: Float, audioStartSeconds: Double) {
    val gain = spec.volume * masterVolume
    val sourceFrames = if (pcm.channels == 0) 0 else pcm.samples.size / pcm.channels
    if (sourceFrames == 0) return

    val trimStart = ((spec.trimStartSeconds ?: 0.0) * pcm.sampleRate).toInt()
    val trimEnd = spec.trimEndSeconds?.let { (it * pcm.sampleRate).toInt() } ?: sourceFrames
    val delayFrames = (spec.delayMs / 1000.0 * sampleRate).toInt()
    val fadeInFrames = ((spec.fadeInSeconds ?: 0.0) * sampleRate).toInt()
    val fadeOutFrames = ((spec.fadeOutSeconds ?: 0.0) * sampleRate).toInt()
    val fadeOutStart = (spec.fadeOutStartSeconds * sampleRate).toInt()

    val firstFrame = (audioStartSeconds * sampleRate).toInt()
    val outputEnd = minOf(firstFrame + totalFrames,
      spec.endSeconds?.let { (it * sampleRate).toInt() } ?: (firstFrame + totalFrames))
    val sourceSpan = minOf(trimEnd, sourceFrames) - trimStart
    if (sourceSpan <= 0 || spec.tempo <= 0 || !spec.tempo.isFinite()) return
    var dst = maxOf(delayFrames, firstFrame)
    var envelopeIndex = 0
    while (dst < outputEnd) {
      val localSeconds = (dst - delayFrames).toDouble() / sampleRate
      val map = spec.sourceTimeMap
      val sourceSeconds = if (map.size >= 2 && spec.timeMapFps > 0) {
        val position = localSeconds * spec.timeMapFps
        if (position >= map.size - 1) break
        val index = position.toInt()
        map[index] + (map[index + 1] - map[index]) * (position - index)
      } else localSeconds * spec.tempo
      var sourceOffset = (sourceSeconds * pcm.sampleRate).toInt()
      if (spec.loop) sourceOffset %= sourceSpan
      if (sourceOffset >= sourceSpan) break
      val sourceFrame = trimStart + sourceOffset
      var envelope = gain
      val rel = dst - delayFrames
      val seconds = rel.toDouble() / sampleRate
      val points = spec.volumeEnvelope
      if (points.isNotEmpty()) {
        while (envelopeIndex + 1 < points.size && points[envelopeIndex + 1].first <= seconds) envelopeIndex++
        val a = points[envelopeIndex]
        val value = if (seconds <= points.first().first) points.first().second
          else if (envelopeIndex + 1 == points.size) a.second
          else { val b = points[envelopeIndex + 1]; a.second + (b.second - a.second) * ((seconds - a.first) / (b.first - a.first)).toFloat() }
        envelope *= value.coerceIn(0f, 1f)
      }
      if (fadeInFrames > 0 && rel < fadeInFrames) envelope *= rel.toFloat() / fadeInFrames
      if (fadeOutFrames > 0 && dst >= fadeOutStart) {
        val into = dst - fadeOutStart
        envelope *= (1f - into.toFloat() / fadeOutFrames).coerceIn(0f, 1f)
      }
      for (ch in 0 until channels) {
        val sourceChannel = if (pcm.channels == 1) 0 else ch
        val sample = pcm.samples[sourceFrame * pcm.channels + sourceChannel] / 32768f
        mix[(dst - firstFrame) * channels + ch] += sample * envelope
      }
      dst++
    }
  }

}
