import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation

/// Validates the method-channel allocation before multiplying caller dimensions.
struct FrameExtractionRequest {
  let path: String
  let indices: [Int]
  let width: Int
  let height: Int
  let byteCount: Int

  init?(arguments: Any?) {
    guard let map = arguments as? [String: Any],
      let path = map["path"] as? String, !path.isEmpty,
      let indices = map["indices"] as? [Int], indices.allSatisfy({ $0 >= 0 }),
      let width = map["width"] as? Int, width > 0,
      let height = map["height"] as? Int, height > 0
    else { return nil }
    let limit = 256 * 1024 * 1024
    guard width <= limit / 4, height <= limit / (width * 4) else { return nil }
    let frameBytes = width * height * 4
    guard indices.count <= limit / frameBytes else { return nil }
    self.path = path
    self.indices = indices
    self.width = width
    self.height = height
    self.byteCount = indices.count * frameBytes
  }
}

private enum VideoReadError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

/// Reads display-oriented clip frames without FFmpeg. Use only on the plugin's
/// serial worker queue: AVFoundation work and the small index cache stay off the
/// main thread. Decoded images are never cached here.
final class VideoFrameReader {
  // Bound retained timestamps to ~32 MiB and four open asset descriptions.
  private let maxIndexedFrames = 1_000_000
  private var cache: [IndexedVideo] = []

  func probe(path: String) throws -> [String: Any] {
    return try indexedVideo(path: path).facts
  }

  /// The wire format matches Android: one packed, premultiplied RGBA8888 block
  /// per requested index, including duplicates, in the caller's original order.
  func extractFrames(_ request: FrameExtractionRequest) throws -> Data {
    if request.indices.isEmpty { return Data() }
    let video = try indexedVideo(path: request.path)
    guard request.indices.allSatisfy({ $0 < video.times.count }) else {
      throw VideoReadError.invalid("A requested source frame is outside 0..<\(video.times.count).")
    }
    let generator = AVAssetImageGenerator(asset: video.asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = CGSize(width: CGFloat(request.width), height: CGFloat(request.height))
    defer { generator.cancelAllCGImageGeneration() }

    var result = Data(count: request.byteCount)
    let frameBytes = request.width * request.height * 4
    try result.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
      guard let base = raw.baseAddress else {
        throw VideoReadError.invalid("Could not allocate the frame buffer.")
      }
      for (offset, index) in request.indices.enumerated() {
        try autoreleasepool {
          var actualTime = CMTime.invalid
          let image = try generator.copyCGImage(at: video.times[index], actualTime: &actualTime)
          guard CMTimeCompare(actualTime, video.times[index]) == 0 else {
            throw VideoReadError.invalid("The decoder did not return exact source frame \(index).")
          }
          try Self.drawRGBA(
            image, into: base.advanced(by: offset * frameBytes),
            width: request.width, height: request.height
          )
        }
      }
    }
    return result
  }

  /// A bitmap context writes tightly packed rows in CGImage order. Do not apply
  /// a UIKit coordinate flip: this buffer is pixel data, not a UIKit view.
  static func drawRGBA(_ image: CGImage, into data: UnsafeMutableRawPointer,
                       width: Int, height: Int) throws {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: data, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: space,
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { throw VideoReadError.invalid("Could not create the RGBA bitmap context.") }
    context.interpolationQuality = .high
    context.setBlendMode(.copy)
    context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
  }

  private func indexedVideo(path: String) throws -> IndexedVideo {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let identity = try FileIdentity(url: url)
    if let index = cache.firstIndex(where: { $0.identity == identity }) {
      let cached = cache.remove(at: index)
      cache.append(cached)
      return cached
    }
    // Replacing a file at the same path invalidates its previous frame index.
    cache.removeAll { $0.identity.url == url }
    let video = try IndexedVideo(identity: identity, maxFrames: maxIndexedFrames)
    guard try FileIdentity(url: url) == identity else {
      throw VideoReadError.invalid("The video changed while it was being indexed.")
    }
    while !cache.isEmpty &&
      (cache.count >= 4 || cache.reduce(0, { $0 + $1.times.count }) + video.times.count > maxIndexedFrames) {
      cache.removeFirst()
    }
    cache.append(video)
    return video
  }
}

private struct FileIdentity: Equatable {
  let url: URL
  let size: Int
  let modified: Date

  init(url: URL) throws {
    var freshURL = url
    freshURL.removeAllCachedResourceValues()
    let values = try freshURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
    guard values.isRegularFile == true, let size = values.fileSize,
      let modified = values.contentModificationDate
    else { throw VideoReadError.invalid("The clip must be a readable local video file.") }
    self.url = url
    self.size = size
    self.modified = modified
  }
}

private final class IndexedVideo {
  let identity: FileIdentity
  let asset: AVAsset
  let times: [CMTime]
  let facts: [String: Any]

  init(identity: FileIdentity, maxFrames: Int) throws {
    let asset = AVURLAsset(url: identity.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    let videoTracks = asset.tracks(withMediaType: .video)
    guard let track = videoTracks.first else {
      throw VideoReadError.invalid("The file contains no video track.")
    }
    let bounds = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform).standardized
    // A muxed audio tail is not part of the first video track's clip window.
    let seconds = CMTimeGetSeconds(track.timeRange.duration)
    guard bounds.width.isFinite, bounds.height.isFinite,
      bounds.width >= 1, bounds.height >= 1,
      bounds.width < CGFloat(Int32.max), bounds.height < CGFloat(Int32.max),
      seconds.isFinite, seconds > 0, seconds < Double(Int64.max) / 1_000_000
    else { throw VideoReadError.invalid("The video has invalid dimensions or duration.") }
    let times = try Self.presentationTimes(asset: asset, track: track, maxFrames: maxFrames)
    guard !times.isEmpty else { throw VideoReadError.invalid("The video contains no displayable frames.") }
    let nominalFps = Double(track.nominalFrameRate)
    let fps = nominalFps.isFinite && nominalFps > 0 ? nominalFps : Double(times.count) / seconds
    guard fps.isFinite, fps > 0 else { throw VideoReadError.invalid("The video has no usable frame rate.") }
    var codec = "unknown"
    if let descriptions = track.formatDescriptions as? [CMFormatDescription], let format = descriptions.first {
      let type = CMFormatDescriptionGetMediaSubType(format)
      switch type {
      case kCMVideoCodecType_H264: codec = "h264"
      case kCMVideoCodecType_HEVC: codec = "hevc"
      default:
        let bytes: [UInt8] = [24, 16, 8, 0].map { UInt8((type >> $0) & 0xff) }
        codec = String(bytes: bytes, encoding: .ascii) ?? "unknown"
      }
    }
    // Match the probe's first-video-track contract even for a file containing
    // multiple video tracks. Keep the original timeline start and transform.
    let imageAsset: AVAsset
    if videoTracks.count == 1 && track.isEnabled {
      imageAsset = asset
    } else {
      let isolated = AVMutableComposition()
      guard let imageTrack = isolated.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
      ) else { throw VideoReadError.invalid("Cannot create the frame extraction track.") }
      try imageTrack.insertTimeRange(track.timeRange, of: track, at: track.timeRange.start)
      imageTrack.preferredTransform = track.preferredTransform
      imageAsset = isolated
    }
    self.identity = identity
    self.asset = imageAsset
    self.times = times
    self.facts = [
      "width": Int(bounds.width.rounded()), "height": Int(bounds.height.rounded()),
      "frameCount": times.count, "durationMs": Int((seconds * 1000).rounded()),
      "durationUs": Int((seconds * 1_000_000).rounded()),
      "codec": codec, "fps": fps, "hasAudio": !asset.tracks(withMediaType: .audio).isEmpty,
      "timeline": ["schemaVersion": 1,
        "presentationTimesUs": times.map { Int(((CMTimeGetSeconds($0) - CMTimeGetSeconds(times[0])) * 1_000_000).rounded()) },
        "durationUs": Int((seconds * 1_000_000).rounded())],
    ]
  }

  /// Compressed samples arrive in decode order. Sort their individual PTS values
  /// to map source ordinals to presentation order, including fractional/VFR
  /// clocks, rather than guessing `index / nominalFrameRate`.
  private static func presentationTimes(asset: AVAsset, track: AVAssetTrack, maxFrames: Int) throws -> [CMTime] {
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw VideoReadError.invalid("Cannot read this video track.") }
    reader.add(output)
    reader.timeRange = track.timeRange
    guard reader.startReading() else {
      throw VideoReadError.invalid(reader.error?.localizedDescription ?? "Cannot start reading the video.")
    }
    defer { reader.cancelReading() }
    var times: [CMTime] = []
    let end = CMTimeRangeGetEnd(track.timeRange)
    while true {
      let hasSample = try autoreleasepool { () throws -> Bool in
        guard let buffer = output.copyNextSampleBuffer() else { return false }
        for index in 0..<CMSampleBufferGetNumSamples(buffer) {
          var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid)
          guard CMSampleBufferGetSampleTimingInfo(buffer, at: index, timingInfoOut: &timing) == noErr,
            CMTimeGetSeconds(timing.presentationTimeStamp).isFinite
          else { throw VideoReadError.invalid("The video contains an invalid frame timestamp.") }
          let time = timing.presentationTimeStamp
          if CMTimeCompare(time, track.timeRange.start) >= 0 && CMTimeCompare(time, end) < 0 {
            guard times.count < maxFrames else {
              throw VideoReadError.invalid("The clip exceeds the one-million-frame index budget; split it into shorter clips.")
            }
            times.append(time)
          }
        }
        return true
      }
      if !hasSample { break }
    }
    guard reader.status == .completed else {
      throw VideoReadError.invalid(reader.error?.localizedDescription ?? "The video frame index could not be read.")
    }
    return times.sorted { CMTimeCompare($0, $1) < 0 }
  }
}
