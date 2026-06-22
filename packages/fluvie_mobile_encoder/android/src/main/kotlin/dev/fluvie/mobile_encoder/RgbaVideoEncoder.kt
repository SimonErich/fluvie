package dev.fluvie.mobile_encoder

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.RandomAccessFile
import java.nio.ByteBuffer

/**
 * Encodes a raw RGBA8888 frames file into an MP4 using the platform hardware
 * encoder.
 *
 * The frames file holds [EncodeRequest.frameCount] frames of
 * `width * height * 4` bytes, row-major. Each is read, converted to YUV420 into
 * the encoder's flexible input image (which handles device-specific plane
 * strides), and queued with a presentation time derived from the frame index
 * and fps, so the encode carries no wall-clock. The encoded chunks are written
 * to an MP4 container by [MediaMuxer].
 */
class RgbaVideoEncoder(private val request: EncodeRequest) {
  fun encode(outputPath: String) {
    val mime = if (request.codec == "hevc") {
      MediaFormat.MIMETYPE_VIDEO_HEVC
    } else {
      MediaFormat.MIMETYPE_VIDEO_AVC
    }
    val format = MediaFormat.createVideoFormat(mime, request.width, request.height).apply {
      setInteger(
        MediaFormat.KEY_COLOR_FORMAT,
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
      )
      setInteger(MediaFormat.KEY_BIT_RATE, request.bitRate)
      setInteger(MediaFormat.KEY_FRAME_RATE, request.fps)
      setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
    }

    val codec = MediaCodec.createEncoderByType(mime)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()
    val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

    val bufferInfo = MediaCodec.BufferInfo()
    val frameBytes = request.width * request.height * 4
    // The encoder's input buffer holds YUV420 (12 bits/px), not the source RGBA
    // (32 bits/px): queueInputBuffer's size must describe the YUV payload, or it
    // overruns the smaller YUV buffer's capacity.
    val yuvBytes = request.width * request.height * 3 / 2
    val rgba = ByteArray(frameBytes)
    var trackIndex = -1
    var muxing = false

    try {
      RandomAccessFile(request.framesPath, "r").use { file ->
        var frame = 0
        var inputDone = false
        while (true) {
          if (!inputDone) {
            val inputIndex = codec.dequeueInputBuffer(TIMEOUT_US)
            if (inputIndex >= 0) {
              if (frame < request.frameCount) {
                file.seek(frame.toLong() * frameBytes)
                file.readFully(rgba)
                val image = codec.getInputImage(inputIndex)
                  ?: throw IllegalStateException("encoder returned no input image")
                writeYuv420(image, rgba, request.width, request.height)
                val ptsUs = frame.toLong() * 1_000_000L / request.fps
                codec.queueInputBuffer(inputIndex, 0, yuvBytes, ptsUs, 0)
                frame++
              } else {
                codec.queueInputBuffer(
                  inputIndex,
                  0,
                  0,
                  0,
                  MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                )
                inputDone = true
              }
            }
          }

          val outputIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
          if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            trackIndex = muxer.addTrack(codec.outputFormat)
            muxer.start()
            muxing = true
          } else if (outputIndex >= 0) {
            val encoded = codec.getOutputBuffer(outputIndex)
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
              bufferInfo.size = 0
            }
            if (encoded != null && bufferInfo.size > 0 && muxing) {
              encoded.position(bufferInfo.offset)
              encoded.limit(bufferInfo.offset + bufferInfo.size)
              muxer.writeSampleData(trackIndex, encoded, bufferInfo)
            }
            codec.releaseOutputBuffer(outputIndex, false)
            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
          }
        }
      }
    } finally {
      codec.stop()
      codec.release()
      if (muxing) muxer.stop()
      muxer.release()
    }
  }

  /**
   * Fills [image]'s Y/U/V planes from packed [rgba] using the BT.601 limited
   * range matrix, honoring each plane's row and pixel stride (so NV12 and I420
   * device layouts both work).
   */
  private fun writeYuv420(image: Image, rgba: ByteArray, width: Int, height: Int) {
    val y = image.planes[0]
    val u = image.planes[1]
    val v = image.planes[2]
    val yBuf: ByteBuffer = y.buffer
    val uBuf: ByteBuffer = u.buffer
    val vBuf: ByteBuffer = v.buffer

    for (row in 0 until height) {
      for (col in 0 until width) {
        val i = (row * width + col) * 4
        val r = rgba[i].toInt() and 0xFF
        val g = rgba[i + 1].toInt() and 0xFF
        val b = rgba[i + 2].toInt() and 0xFF

        val luma = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
        yBuf.put(row * y.rowStride + col * y.pixelStride, luma.coerceIn(16, 235).toByte())

        if (row and 1 == 0 && col and 1 == 0) {
          val cb = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
          val cr = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
          val cx = col / 2
          val cy = row / 2
          uBuf.put(cy * u.rowStride + cx * u.pixelStride, cb.coerceIn(16, 240).toByte())
          vBuf.put(cy * v.rowStride + cx * v.pixelStride, cr.coerceIn(16, 240).toByte())
        }
      }
    }
  }

  private companion object {
    const val TIMEOUT_US = 10_000L
  }
}
