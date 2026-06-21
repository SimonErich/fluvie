package dev.fluvie.mobile_encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.nio.ByteBuffer
import java.nio.ByteOrder

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
    )
  }
}

/**
 * Decodes [tracks], mixes them into one stereo 44.1 kHz buffer (applying each
 * track's trim, delay, volume, and fades), and encodes the result to an AAC MP4.
 *
 * The mix math mirrors the FFmpeg path: every value arrives pre-resolved to
 * seconds/milliseconds. Resampling is nearest-neighbour. Looping repeats the
 * trimmed window to fill the render window.
 */
class AudioMixEncoder(
  private val tracks: List<AudioTrackSpec>,
  private val masterVolume: Float,
  private val durationSeconds: Double,
) {
  fun encodeTo(outputPath: String) {
    val totalFrames = (durationSeconds * SAMPLE_RATE).toInt()
    val mix = FloatArray(totalFrames * CHANNELS)
    for (spec in tracks) mixOne(spec, mix, totalFrames)
    encodeAac(mix, outputPath)
  }

  private fun mixOne(spec: AudioTrackSpec, mix: FloatArray, totalFrames: Int) {
    val pcm = PcmAudioDecoder.decode(spec.path)
    val gain = spec.volume * masterVolume
    val sourceFrames = if (pcm.channels == 0) 0 else pcm.samples.size / pcm.channels
    if (sourceFrames == 0) return

    val trimStart = ((spec.trimStartSeconds ?: 0.0) * pcm.sampleRate).toInt()
    val trimEnd = spec.trimEndSeconds?.let { (it * pcm.sampleRate).toInt() } ?: sourceFrames
    val delayFrames = (spec.delayMs / 1000.0 * SAMPLE_RATE).toInt()
    val fadeInFrames = ((spec.fadeInSeconds ?: 0.0) * SAMPLE_RATE).toInt()
    val fadeOutFrames = ((spec.fadeOutSeconds ?: 0.0) * SAMPLE_RATE).toInt()
    val fadeOutStart = (spec.fadeOutStartSeconds * SAMPLE_RATE).toInt()

    var dst = delayFrames
    var pos = trimStart
    while (dst in 0 until totalFrames) {
      if (pos >= trimEnd || pos >= sourceFrames) {
        if (spec.loop && trimEnd > trimStart) {
          pos = trimStart
          continue
        }
        break
      }
      val sourceFrame = (pos.toLong() * pcm.sampleRate / SAMPLE_RATE).toInt()
      if (sourceFrame >= sourceFrames) break

      var envelope = gain
      val rel = dst - delayFrames
      if (fadeInFrames > 0 && rel < fadeInFrames) envelope *= rel.toFloat() / fadeInFrames
      if (fadeOutFrames > 0 && rel >= fadeOutStart) {
        val into = rel - fadeOutStart
        envelope *= (1f - into.toFloat() / fadeOutFrames).coerceIn(0f, 1f)
      }
      for (ch in 0 until CHANNELS) {
        val sourceChannel = if (pcm.channels == 1) 0 else ch
        val sample = pcm.samples[sourceFrame * pcm.channels + sourceChannel] / 32768f
        mix[dst * CHANNELS + ch] += sample * envelope
      }
      dst++
      pos++
    }
  }

  private fun encodeAac(mix: FloatArray, outputPath: String) {
    val format = MediaFormat.createAudioFormat(
      MediaFormat.MIMETYPE_AUDIO_AAC,
      SAMPLE_RATE,
      CHANNELS,
    ).apply {
      setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
      setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
    }
    val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()
    val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

    val pcm = ByteBuffer.allocate(mix.size * 2).order(ByteOrder.nativeOrder())
    for (sample in mix) {
      pcm.putShort((sample.coerceIn(-1f, 1f) * 32767f).toInt().toShort())
    }
    pcm.flip()

    val info = MediaCodec.BufferInfo()
    var trackIndex = -1
    var muxing = false
    var presentationUs = 0L
    var inputDone = false
    try {
      while (true) {
        if (!inputDone) {
          val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
          if (inIndex >= 0) {
            val buffer = codec.getInputBuffer(inIndex)!!
            buffer.clear()
            val chunk = minOf(buffer.capacity(), pcm.remaining())
            if (chunk <= 0) {
              codec.queueInputBuffer(
                inIndex,
                0,
                0,
                presentationUs,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
              )
              inputDone = true
            } else {
              val slice = ByteArray(chunk)
              pcm.get(slice)
              buffer.put(slice)
              codec.queueInputBuffer(inIndex, 0, chunk, presentationUs, 0)
              presentationUs += (chunk / (2 * CHANNELS)).toLong() * 1_000_000L / SAMPLE_RATE
            }
          }
        }
        val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
        if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
          trackIndex = muxer.addTrack(codec.outputFormat)
          muxer.start()
          muxing = true
        } else if (outIndex >= 0) {
          val encoded = codec.getOutputBuffer(outIndex)
          if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
          if (encoded != null && info.size > 0 && muxing) {
            encoded.position(info.offset)
            encoded.limit(info.offset + info.size)
            muxer.writeSampleData(trackIndex, encoded, info)
          }
          codec.releaseOutputBuffer(outIndex, false)
          if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
        }
      }
    } finally {
      codec.stop()
      codec.release()
      if (muxing) muxer.stop()
      muxer.release()
    }
  }

  private companion object {
    const val SAMPLE_RATE = 44100
    const val CHANNELS = 2
    const val TIMEOUT_US = 10_000L
  }
}
