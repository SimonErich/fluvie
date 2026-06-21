package dev.fluvie.mobile_encoder

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.concurrent.Executors

/**
 * Serves the `dev.fluvie/mobile_encoder` channel: encodes a captured RGBA frames
 * file to an MP4 with the device's hardware [android.media.MediaCodec] encoder
 * and [android.media.MediaMuxer]. There is no bundled codec and no FFmpeg.
 *
 * The encode runs on a single background thread so the platform thread is never
 * blocked; the result (or a typed error) is posted back on the main looper.
 */
class FluvieMobileEncoderPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    worker.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method != "encode") {
      result.notImplemented()
      return
    }
    val request = try {
      EncodeRequest.fromCall(call)
    } catch (e: IllegalArgumentException) {
      result.error("bad_request", e.message, null)
      return
    }
    val audioMaps = call.argument<List<Map<String, Any?>>>("audioTracks") ?: emptyList()
    val audioTracks = audioMaps.map { AudioTrackSpec.from(it) }
    val masterVolume = (call.argument<Double>("audioMasterVolume") ?: 1.0).toFloat()

    worker.execute {
      try {
        encode(request, audioTracks, masterVolume)
        main.post { result.success(request.outputPath) }
      } catch (e: Exception) {
        main.post { result.error("encode_failed", e.message, null) }
      }
    }
  }

  private fun encode(
    request: EncodeRequest,
    audioTracks: List<AudioTrackSpec>,
    masterVolume: Float,
  ) {
    if (audioTracks.isEmpty()) {
      RgbaVideoEncoder(request).encode(request.outputPath)
      return
    }
    val parent = File(request.outputPath).parentFile
    val videoOnly = File(parent, "fluvie_video_only.mp4").absolutePath
    val audioOnly = File(parent, "fluvie_audio_only.m4a").absolutePath
    try {
      RgbaVideoEncoder(request).encode(videoOnly)
      AudioMixEncoder(
        audioTracks,
        masterVolume,
        request.frameCount.toDouble() / request.fps,
      ).encodeTo(audioOnly)
      TrackMuxer.combine(videoOnly, audioOnly, request.outputPath)
    } finally {
      File(videoOnly).delete()
      File(audioOnly).delete()
    }
  }

  private companion object {
    const val CHANNEL = "dev.fluvie/mobile_encoder"
  }
}

/** The validated arguments of one `encode` call. */
data class EncodeRequest(
  val framesPath: String,
  val outputPath: String,
  val width: Int,
  val height: Int,
  val fps: Int,
  val frameCount: Int,
  val bitRate: Int,
  val codec: String,
) {
  companion object {
    fun fromCall(call: MethodCall): EncodeRequest {
      fun int(key: String) =
        call.argument<Int>(key) ?: throw IllegalArgumentException("missing int '$key'")
      fun str(key: String) =
        call.argument<String>(key) ?: throw IllegalArgumentException("missing string '$key'")
      return EncodeRequest(
        framesPath = str("framesPath"),
        outputPath = str("outputPath"),
        width = int("width"),
        height = int("height"),
        fps = int("fps"),
        frameCount = int("frameCount"),
        bitRate = int("bitRate"),
        codec = str("codec"),
      )
    }
  }
}
