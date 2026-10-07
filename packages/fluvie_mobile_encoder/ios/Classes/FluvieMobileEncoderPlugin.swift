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
  private let frameReader = VideoFrameReader()

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "encode": handleEncode(call, result: result)
    case "probeVideo": handleProbe(call, result: result)
    case "extractFrames": handleExtract(call, result: result)
    case "decodePcm": handleDecodePcm(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleDecodePcm(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let map = call.arguments as? [String: Any],
      let path = map["path"] as? String, !path.isEmpty,
      let output = map["outputPath"] as? String, !output.isEmpty,
      let maximum = map["maxSamples"] as? Int, maximum > 0
    else {
      result(FlutterError(code: "bad_request", message: "Expected path, outputPath and positive maxSamples", details: nil))
      return
    }
    queue.async {
      do {
        let facts = try NativePcmAnalysis.decode(path: path, outputPath: output, maxSamples: maximum)
        DispatchQueue.main.async { result(facts) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "pcm_decode_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handleProbe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let map = call.arguments as? [String: Any],
      let path = map["path"] as? String, !path.isEmpty
    else {
      result(FlutterError(code: "bad_request", message: "Missing string 'path'.", details: nil))
      return
    }
    queue.async {
      do {
        let facts = try self.frameReader.probe(path: path)
        DispatchQueue.main.async { result(facts) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "probe_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handleExtract(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let request = FrameExtractionRequest(arguments: call.arguments) else {
      result(FlutterError(
        code: "bad_request",
        message: "Expected path, nonnegative frame indices, positive dimensions, and a batch no larger than 256 MiB.",
        details: nil
      ))
      return
    }
    queue.async {
      do {
        let bytes = try self.frameReader.extractFrames(request)
        DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: bytes)) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "extract_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handleEncode(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let request = EncodeRequest(arguments: call.arguments) else {
      result(FlutterError(code: "bad_request", message: "Invalid encode arguments.", details: nil))
      return
    }
    let audioSpecs = ((call.arguments as? [String: Any])?["audioTracks"] as? [[String: Any]] ?? [])
      .compactMap { AudioTrackSpec($0) }
    let masterVolume = Float(
      (call.arguments as? [String: Any])?["audioMasterVolume"] as? Double ?? 1
    )

    let audioStart = (call.arguments as? [String: Any])?["audioStartSeconds"] as? Double ?? 0
    guard audioStart.isFinite, audioStart >= 0 else {
      result(FlutterError(code: "bad_request", message: "audioStartSeconds must be finite and nonnegative", details: nil))
      return
    }
    queue.async {
      do {
        let output = URL(fileURLWithPath: request.outputPath)
        if audioSpecs.isEmpty {
          try RgbaVideoEncoder(request: request).encode(to: output)
        } else {
          let videoOnly = output.deletingLastPathComponent()
            .appendingPathComponent("fluvie_video_only_\(UUID().uuidString).mp4")
          defer { try? FileManager.default.removeItem(at: videoOnly) }
          try RgbaVideoEncoder(request: request).encode(to: videoOnly)
          try AudioComposer(videoURL: videoOnly, tracks: audioSpecs, masterVolume: masterVolume, audioStartSeconds: audioStart)
            .export(to: output)
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
