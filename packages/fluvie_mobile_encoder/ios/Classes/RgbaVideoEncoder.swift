import AVFoundation
import CoreVideo
import Foundation

/// A failure raised while encoding on the device.
enum EncoderError: LocalizedError {
  case setup(String)
  case frame(Int)

  var errorDescription: String? {
    switch self {
    case .setup(let message): return message
    case .frame(let index): return "could not read or append frame \(index)"
    }
  }
}

/// Encodes a raw RGBA8888 frames file into an MP4 with `AVAssetWriter` over the
/// hardware VideoToolbox encoder.
///
/// Each frame (`width * height * 4` bytes, row-major) is copied into a BGRA
/// `CVPixelBuffer` from the adaptor's pool and appended with a presentation time
/// derived from the frame index and fps, so the encode carries no wall-clock.
final class RgbaVideoEncoder {
  private let request: EncodeRequest

  init(request: EncodeRequest) {
    self.request = request
  }

  func encode(to url: URL) throws {
    try? FileManager.default.removeItem(at: url)

    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
      throw EncoderError.setup("could not create AVAssetWriter")
    }

    let codecType: AVVideoCodecType = request.codec == "hevc" ? .hevc : .h264
    let settings: [String: Any] = [
      AVVideoCodecKey: codecType,
      AVVideoWidthKey: request.width,
      AVVideoHeightKey: request.height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: request.bitRate],
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let attributes: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
      kCVPixelBufferWidthKey as String: request.width,
      kCVPixelBufferHeightKey as String: request.height,
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: attributes
    )

    guard writer.canAdd(input) else { throw EncoderError.setup("cannot add the video input") }
    writer.add(input)
    guard writer.startWriting() else {
      throw EncoderError.setup(writer.error?.localizedDescription ?? "startWriting failed")
    }
    writer.startSession(atSourceTime: .zero)

    let frameBytes = request.width * request.height * 4
    guard let handle = FileHandle(forReadingAtPath: request.framesPath) else {
      throw EncoderError.setup("cannot open the frames file")
    }
    defer { try? handle.close() }

    for frame in 0..<request.frameCount {
      let data = handle.readData(ofLength: frameBytes)
      guard data.count == frameBytes else { throw EncoderError.frame(frame) }
      while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }

      guard let pool = adaptor.pixelBufferPool else {
        throw EncoderError.setup("no pixel buffer pool")
      }
      var maybeBuffer: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer)
      guard let buffer = maybeBuffer else { throw EncoderError.frame(frame) }

      try fill(buffer, with: data)
      let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(request.fps))
      guard adaptor.append(buffer, withPresentationTime: time) else {
        throw EncoderError.setup(writer.error?.localizedDescription ?? "append failed")
      }
    }

    input.markAsFinished()
    let group = DispatchGroup()
    group.enter()
    writer.finishWriting { group.leave() }
    group.wait()
    guard writer.status == .completed else {
      throw EncoderError.setup(writer.error?.localizedDescription ?? "writer did not complete")
    }
  }

  /// Copies packed RGBA [data] into [buffer] as BGRA, swizzling the red and blue
  /// channels and honoring the buffer's row padding.
  private func fill(_ buffer: CVPixelBuffer, with data: Data) throws {
    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
      throw EncoderError.setup("no pixel buffer base address")
    }

    let dstStride = CVPixelBufferGetBytesPerRow(buffer)
    let dst = base.assumingMemoryBound(to: UInt8.self)
    let width = request.width
    let height = request.height

    data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      let src = raw.bindMemory(to: UInt8.self)
      for y in 0..<height {
        let srcRow = y * width * 4
        let dstRow = y * dstStride
        for x in 0..<width {
          let si = srcRow + x * 4
          let di = dstRow + x * 4
          dst[di + 0] = src[si + 2]  // B
          dst[di + 1] = src[si + 1]  // G
          dst[di + 2] = src[si + 0]  // R
          dst[di + 3] = src[si + 3]  // A
        }
      }
    }
  }
}
