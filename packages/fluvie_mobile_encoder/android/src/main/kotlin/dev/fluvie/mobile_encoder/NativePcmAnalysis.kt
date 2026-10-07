package dev.fluvie.mobile_encoder

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.SystemClock
import java.io.File

/** Streams compressed music through MediaCodec without retaining boxed PCM samples. */
internal object NativePcmAnalysis {
  fun decode(path: String, outputPath: String, maxSamples: Int): Map<String, Int> {
    require(path.isNotEmpty() && outputPath.isNotEmpty() && maxSamples > 0)
    val output = File(outputPath)
    val extractor = MediaExtractor()
    var codec: MediaCodec? = null
    var started = false
    var completed = false
    try {
      extractor.setDataSource(path)
      val track = (0 until extractor.trackCount).firstOrNull {
        extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
      } ?: throw IllegalArgumentException("No audio track in $path")
      extractor.selectTrack(track)
      val format = extractor.getTrackFormat(track)
      var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
      var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
      var floatPcm = false
      val decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
      codec = decoder
      decoder.configure(format, null, null, 0)
      decoder.start()
      started = true
      val info = MediaCodec.BufferInfo()
      var inputDone = false
      var sampleCount = 0
      var lastProgress = SystemClock.elapsedRealtime()
      output.outputStream().buffered().use { sink ->
        while (true) {
          check(SystemClock.elapsedRealtime() - lastProgress < 30000) { "Native audio decoder stalled" }
          if (!inputDone) {
            val index = decoder.dequeueInputBuffer(10000)
            if (index >= 0) {
              val buffer = decoder.getInputBuffer(index)!!
              buffer.clear()
              val size = extractor.readSampleData(buffer, 0)
              if (size < 0) {
                decoder.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                inputDone = true
              } else {
                decoder.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                extractor.advance()
              }
            }
          }
          val index = decoder.dequeueOutputBuffer(info, 10000)
          if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            val actual = decoder.outputFormat
            val actualRate = actual.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            require(sampleCount == 0 || rate == actualRate) { "PCM sample rate changed during decode" }
            rate = actualRate
            channels = actual.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val encoding = if (actual.containsKey(MediaFormat.KEY_PCM_ENCODING))
              actual.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
            require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT)
            floatPcm = encoding == AudioFormat.ENCODING_PCM_FLOAT
          } else if (index >= 0) {
            try {
              if (info.size > 0) {
                sampleCount += PcmMonoWriter.write(decoder.getOutputBuffer(index)!!,
                  info.offset, info.size, channels, floatPcm, sink, maxSamples - sampleCount)
                lastProgress = SystemClock.elapsedRealtime()
              }
            } finally { decoder.releaseOutputBuffer(index, false) }
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
          }
        }
      }
      require(rate > 0)
      completed = true
      return mapOf("sampleRate" to rate, "sampleCount" to sampleCount)
    } finally {
      if (started) codec?.stop()
      codec?.release()
      extractor.release()
      if (!completed) output.delete()
    }
  }
}
