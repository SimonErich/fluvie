import Flutter
import Foundation

/// Serves the `dev.fluvie/mobile_encoder` channel on iOS: encodes a captured
/// RGBA frames file into an MP4 with AVFoundation over the device's hardware
/// VideoToolbox encoder. No FFmpeg and no bundled codec.
///
/// The encode runs on a background queue so the platform thread is never
/// blocked; the output path (or a typed error) is returned on the main queue.
public class FluvieMobileEncoderPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.fluvie/mobile_encoder",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(FluvieMobileEncoderPlugin(), channel: channel)
  }

  private let queue = DispatchQueue(label: "dev.fluvie.mobile_encoder", qos: .userInitiated)

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "encode" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let request = EncodeRequest(arguments: call.arguments) else {
      result(FlutterError(code: "bad_request", message: "Invalid encode arguments.", details: nil))
      return
    }
    let audioSpecs = ((call.arguments as? [String: Any])?["audioTracks"] as? [[String: Any]] ?? [])
      .compactMap { AudioTrackSpec($0) }
    let masterVolume = Float(
      (call.arguments as? [String: Any])?["audioMasterVolume"] as? Double ?? 1
    )

    queue.async {
      do {
        let output = URL(fileURLWithPath: request.outputPath)
        if audioSpecs.isEmpty {
          try RgbaVideoEncoder(request: request).encode(to: output)
        } else {
          let videoOnly = output.deletingLastPathComponent()
            .appendingPathComponent("fluvie_video_only.mp4")
          try RgbaVideoEncoder(request: request).encode(to: videoOnly)
          try AudioComposer(videoURL: videoOnly, tracks: audioSpecs, masterVolume: masterVolume)
            .export(to: output)
          try? FileManager.default.removeItem(at: videoOnly)
        }
        DispatchQueue.main.async { result(request.outputPath) }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "encode_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}

/// The validated arguments of one `encode` call.
struct EncodeRequest {
  let framesPath: String
  let outputPath: String
  let width: Int
  let height: Int
  let fps: Int
  let frameCount: Int
  let bitRate: Int
  let codec: String

  init?(arguments: Any?) {
    guard
      let map = arguments as? [String: Any],
      let framesPath = map["framesPath"] as? String,
      let outputPath = map["outputPath"] as? String,
      let width = map["width"] as? Int,
      let height = map["height"] as? Int,
      let fps = map["fps"] as? Int,
      let frameCount = map["frameCount"] as? Int,
      let bitRate = map["bitRate"] as? Int,
      let codec = map["codec"] as? String
    else { return nil }
    self.framesPath = framesPath
    self.outputPath = outputPath
    self.width = width
    self.height = height
    self.fps = fps
    self.frameCount = frameCount
    self.bitRate = bitRate
    self.codec = codec
  }
}
