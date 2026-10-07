import AVFoundation
import Foundation

/// Decodes the first audio track to bounded mono float32 PCM for Fluvie's DSP.
enum NativePcmAnalysis {
  static func decode(path: String, outputPath: String, maxSamples: Int) throws -> [String: Int] {
    guard !path.isEmpty, !outputPath.isEmpty, maxSamples > 0 else {
      throw failure("Invalid PCM analysis request")
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .audio).first else {
      throw failure("No audio track in \(path)")
    }
    let description = track.formatDescriptions.first as? CMAudioFormatDescription
    let sourceRate = description.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0) }
      .map { $0.pointee.mSampleRate } ?? 44100
    guard sourceRate.isFinite, sourceRate > 0 else { throw failure("Invalid source sample rate") }
    let rate = Int(sourceRate.rounded())
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: rate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ])
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw failure("Unsupported audio analysis format") }
    reader.add(output)
    let url = URL(fileURLWithPath: outputPath)
    guard FileManager.default.createFile(atPath: outputPath, contents: nil) else {
      throw failure("Cannot create PCM analysis file")
    }
    let sink = try FileHandle(forWritingTo: url)
    var completed = false
    defer {
      reader.cancelReading()
      try? sink.close()
      if !completed { try? FileManager.default.removeItem(at: url) }
    }
    guard reader.startReading() else { throw reader.error ?? failure("Cannot start audio decoder") }
    var sampleCount = 0
    while let sample = output.copyNextSampleBuffer() {
      guard let block = CMSampleBufferGetDataBuffer(sample) else {
        throw failure("Missing decoded PCM buffer")
      }
      let length = CMBlockBufferGetDataLength(block)
      guard length % 4 == 0, length / 4 <= maxSamples - sampleCount else {
        throw failure("Audio exceeds the configured PCM analysis sample limit")
      }
      var data = Data(count: length)
      let status = data.withUnsafeMutableBytes { bytes in
        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
      }
      guard status == kCMBlockBufferNoErr else { throw failure("Cannot read decoded PCM buffer") }
      data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
        for index in stride(from: 0, to: length, by: 4) {
          let bits = bytes.loadUnaligned(fromByteOffset: index, as: UInt32.self).littleEndian
          let value = Float(bitPattern: bits)
          if !value.isFinite { continue }
          var normalized = min(1, max(-1, value)).bitPattern.littleEndian
          withUnsafeBytes(of: &normalized) { UnsafeMutableRawBufferPointer(rebasing: bytes[index..<(index + 4)]).copyBytes(from: $0) }
        }
      }
      // Dart validates finite normalized samples too, so corrupt codec output
      // cannot enter FFT analysis even if the native decoder reports success.
      try sink.write(contentsOf: data)
      sampleCount += length / 4
    }
    guard reader.status == .completed else { throw reader.error ?? failure("Audio decode did not complete") }
    completed = true
    return ["sampleRate": rate, "sampleCount": sampleCount]
  }

  private static func failure(_ message: String) -> NSError {
    NSError(domain: "dev.fluvie.mobile_encoder", code: 1,
      userInfo: [NSLocalizedDescriptionKey: message])
  }
}
