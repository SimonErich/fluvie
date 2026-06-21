package dev.fluvie.mobile_encoder

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import java.nio.ByteBuffer

/** Muxes a video-only MP4 and an audio-only MP4 into one MP4 (no re-encoding). */
object TrackMuxer {
  fun combine(videoPath: String, audioPath: String, outputPath: String) {
    val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    val video = MediaExtractor().apply { setDataSource(videoPath) }
    val audio = MediaExtractor().apply { setDataSource(audioPath) }
    try {
      selectFirst(video, "video/")
      selectFirst(audio, "audio/")
      val outVideo = muxer.addTrack(trackFormat(video, "video/"))
      val outAudio = muxer.addTrack(trackFormat(audio, "audio/"))
      muxer.start()
      copy(video, muxer, outVideo)
      copy(audio, muxer, outAudio)
      muxer.stop()
    } finally {
      muxer.release()
      video.release()
      audio.release()
    }
  }

  private fun selectFirst(extractor: MediaExtractor, prefix: String) {
    for (i in 0 until extractor.trackCount) {
      val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
      if (mime?.startsWith(prefix) == true) {
        extractor.selectTrack(i)
        return
      }
    }
    throw IllegalStateException("no $prefix track")
  }

  private fun trackFormat(extractor: MediaExtractor, prefix: String): MediaFormat {
    for (i in 0 until extractor.trackCount) {
      val format = extractor.getTrackFormat(i)
      if (format.getString(MediaFormat.KEY_MIME)?.startsWith(prefix) == true) return format
    }
    throw IllegalStateException("no $prefix track")
  }

  private fun copy(extractor: MediaExtractor, muxer: MediaMuxer, dstTrack: Int) {
    val buffer = ByteBuffer.allocate(1 shl 20)
    val info = MediaCodec.BufferInfo()
    while (true) {
      val size = extractor.readSampleData(buffer, 0)
      if (size < 0) break
      info.offset = 0
      info.size = size
      info.presentationTimeUs = extractor.sampleTime
      info.flags = if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) {
        MediaCodec.BUFFER_FLAG_KEY_FRAME
      } else {
        0
      }
      muxer.writeSampleData(dstTrack, buffer, info)
      extractor.advance()
    }
  }
}
