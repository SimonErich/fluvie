package dev.fluvie.mobile_encoder

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.nio.ByteOrder

/** Decoded PCM: interleaved 16-bit samples plus their sample rate and channels. */
data class DecodedPcm(val samples: ShortArray, val sampleRate: Int, val channels: Int)

/** Decodes a compressed audio file to interleaved 16-bit PCM via [MediaCodec]. */
object PcmAudioDecoder {
  fun decode(path: String): DecodedPcm {
    val extractor = MediaExtractor()
    extractor.setDataSource(path)
    var trackIndex = -1
    var format: MediaFormat? = null
    for (i in 0 until extractor.trackCount) {
      val candidate = extractor.getTrackFormat(i)
      if (candidate.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
        trackIndex = i
        format = candidate
        break
      }
    }
    if (trackIndex < 0 || format == null) {
      extractor.release()
      throw IllegalStateException("no audio track in $path")
    }
    extractor.selectTrack(trackIndex)

    val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
    val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
    val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
    codec.configure(format, null, null, 0)
    codec.start()

    val out = ArrayList<Short>()
    val info = MediaCodec.BufferInfo()
    var inputDone = false
    try {
      while (true) {
        if (!inputDone) {
          val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
          if (inIndex >= 0) {
            val buffer = codec.getInputBuffer(inIndex)!!
            val size = extractor.readSampleData(buffer, 0)
            if (size < 0) {
              codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
              inputDone = true
            } else {
              codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
              extractor.advance()
            }
          }
        }
        val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
        if (outIndex >= 0) {
          val buffer = codec.getOutputBuffer(outIndex)
          if (buffer != null && info.size > 0) {
            val shorts = buffer.order(ByteOrder.nativeOrder()).asShortBuffer()
            while (shorts.hasRemaining()) out.add(shorts.get())
          }
          codec.releaseOutputBuffer(outIndex, false)
          if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
        }
      }
    } finally {
      codec.stop()
      codec.release()
      extractor.release()
    }
    return DecodedPcm(out.toShortArray(), sampleRate, channels)
  }

  private const val TIMEOUT_US = 10_000L
}
