package dev.fluvie.mobile_encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

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
  private val audioStartSeconds: Double = 0.0,
) {
  fun encodeTo(outputPath: String): Int {
    val totalFrames = (durationSeconds * SAMPLE_RATE).toInt()
    val mix = FloatArray(totalFrames * CHANNELS)
    for (spec in tracks) PcmTrackMixer.mix(spec, PcmAudioDecoder.decode(spec.path), mix,
      totalFrames, SAMPLE_RATE, CHANNELS, masterVolume, audioStartSeconds)
    val selected = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
    val codecName = selected.name
    selected.release()
    val delay = synchronized(primingByCodec) {
      primingByCodec.getOrPut(codecName) {
        val calibration = File(File(outputPath).parentFile, "fluvie_aac_calibration.m4a")
        try {
          encodeAac(AacDelayCalibration.signal(CHANNELS), calibration.path, codecName)
          val decoded = PcmAudioDecoder.decode(calibration.path)
          require(decoded.sampleRate == SAMPLE_RATE && decoded.channels == CHANNELS)
          AacDelayCalibration.measure(decoded.samples, decoded.channels)
        } finally {
          calibration.delete()
        }
      }
    }
    // Some codec implementations do not flush all delayed samples at EOS.
    // Explicit silence drains priming plus two AAC blocks; elst crops the tail.
    encodeAac(mix, outputPath, codecName, delay + 2048)
    return delay
  }

  private fun encodeAac(mix: FloatArray, outputPath: String, codecName: String, paddingFrames: Int = 0) {
    val format = MediaFormat.createAudioFormat(
      MediaFormat.MIMETYPE_AUDIO_AAC,
      SAMPLE_RATE,
      CHANNELS,
    ).apply {
      setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
      setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
    }
    val codec = MediaCodec.createByCodecName(codecName)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()
    val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

    val pcm = ByteBuffer.allocate((mix.size + paddingFrames * CHANNELS) * 2).order(ByteOrder.nativeOrder())
    for (sample in mix) {
      pcm.putShort((sample.coerceIn(-1f, 1f) * 32767f).toInt().toShort())
    }
    repeat(paddingFrames * CHANNELS) { pcm.putShort(0) }
    pcm.flip()

    val info = MediaCodec.BufferInfo()
    var trackIndex = -1
    var muxing = false
    var inputFrames = 0L
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
                inputFrames * 1_000_000L / SAMPLE_RATE,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
              )
              inputDone = true
            } else {
              val slice = ByteArray(chunk)
              pcm.get(slice)
              buffer.put(slice)
              codec.queueInputBuffer(inIndex, 0, chunk, inputFrames * 1_000_000L / SAMPLE_RATE, 0)
              inputFrames += chunk / (2 * CHANNELS)
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
    val primingByCodec = mutableMapOf<String, Int>()
    const val SAMPLE_RATE = 44100
    const val CHANNELS = 2
    const val TIMEOUT_US = 10_000L
  }
}
