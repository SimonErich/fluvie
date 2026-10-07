import AVFoundation
import Foundation

/// One audio track to mix, as sent over the channel.
struct AudioTrackSpec {
  let path: String
  let delayMs: Int
  let volume: Float
  let trimStartSeconds: Double?
  let trimEndSeconds: Double?
  let fadeInSeconds: Double?
  let fadeOutSeconds: Double?
  let fadeOutStartSeconds: Double
  let loop: Bool
  let volumeEnvelope: [(Double, Float)]
  let endSeconds: Double?
  let tempo: Double
  let timeMapFps: Double
  let sourceTimeMap: [Double]

  init?(_ map: [String: Any]) {
    guard let path = map["path"] as? String else { return nil }
    self.path = path
    self.delayMs = map["delayMs"] as? Int ?? 0
    self.volume = Float(map["volume"] as? Double ?? 1)
    self.trimStartSeconds = map["trimStartSeconds"] as? Double
    self.trimEndSeconds = map["trimEndSeconds"] as? Double
    self.fadeInSeconds = map["fadeInSeconds"] as? Double
    self.fadeOutSeconds = map["fadeOutSeconds"] as? Double
    self.fadeOutStartSeconds = map["fadeOutStartSeconds"] as? Double ?? 0
    self.loop = map["loop"] as? Bool ?? false
    self.endSeconds = map["endSeconds"] as? Double
    self.tempo = map["tempo"] as? Double ?? 1
    let timeMap = map["timeMap"] as? [String: Any]
    self.timeMapFps = (timeMap?["fps"] as? NSNumber)?.doubleValue ?? 0
    self.sourceTimeMap = timeMap?["sourceSeconds"] as? [Double] ?? []
    self.volumeEnvelope = (map["volumeEnvelope"] as? [[String: Any]] ?? []).compactMap { point in
      guard let time = point["seconds"] as? Double, let value = point["value"] as? Double else { return nil }
      return (time, Float(value))
    }
  }
}

/// Mixes [tracks] onto the already-encoded video at [videoURL] and writes the
/// final MP4 to [outputURL], using AVFoundation's own decoder, mixer (volume
/// ramps render the fades), and AAC encoder.
///
/// Each track is inserted at its [AudioTrackSpec.delayMs] offset, trimmed to its
/// `[trimStart, trimEnd]` window, and gained by `volume * masterVolume`; fade-in
/// and fade-out become volume ramps. A looping track tiles its trimmed range to
/// fill the video duration, matching Android and the FFmpeg path.
final class AudioComposer {
  private let videoURL: URL
  private let tracks: [AudioTrackSpec]
  private let masterVolume: Float
  private let audioStartSeconds: Double

  init(videoURL: URL, tracks: [AudioTrackSpec], masterVolume: Float, audioStartSeconds: Double = 0) {
    self.videoURL = videoURL
    self.tracks = tracks
    self.masterVolume = masterVolume
    self.audioStartSeconds = audioStartSeconds
  }

  func export(to outputURL: URL) throws {
    try? FileManager.default.removeItem(at: outputURL)
    let composition = AVMutableComposition()
    let videoAsset = AVURLAsset(url: videoURL)

    guard
      let sourceVideo = videoAsset.tracks(withMediaType: .video).first,
      let compositionVideo = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )
    else { throw EncoderError.setup("no video track to compose") }
    try compositionVideo.insertTimeRange(
      CMTimeRange(start: .zero, duration: videoAsset.duration),
      of: sourceVideo,
      at: CMTime(seconds: audioStartSeconds, preferredTimescale: 44100)
    )

    let durationSeconds = CMTimeGetSeconds(videoAsset.duration)
    var parameters: [AVMutableAudioMixInputParameters] = []
    for spec in tracks {
      if let params = try insert(spec, into: composition, fillTo: durationSeconds + audioStartSeconds) {
        parameters.append(params)
      }
    }

    let audioMix = AVMutableAudioMix()
    audioMix.inputParameters = parameters

    guard
      let session = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetHighestQuality
      )
    else { throw EncoderError.setup("could not create export session") }
    session.outputURL = outputURL
    session.outputFileType = .mp4
    session.audioMix = audioMix
    session.timeRange = CMTimeRange(start: CMTime(seconds: audioStartSeconds, preferredTimescale: 44100),
      duration: videoAsset.duration)
    // Explicitly retain pitch for the scaled source ranges (including ramps).
    session.audioTimePitchAlgorithm = .spectral

    let group = DispatchGroup()
    group.enter()
    session.exportAsynchronously { group.leave() }
    group.wait()
    guard session.status == .completed else {
      throw EncoderError.setup(session.error?.localizedDescription ?? "audio export failed")
    }
  }

  private func insert(
    _ spec: AudioTrackSpec,
    into composition: AVMutableComposition,
    fillTo durationSeconds: Double
  ) throws -> AVMutableAudioMixInputParameters? {
    let durationSeconds = min(durationSeconds, spec.endSeconds ?? durationSeconds)
    let at = CMTime(value: CMTimeValue(spec.delayMs), timescale: 1000)
    // A placement outside its owner/output contributes no samples. Refuse it
    // before creating an empty track or constructing a descending ramp range.
    guard at.seconds < durationSeconds else { return nil }
    let asset = AVURLAsset(url: URL(fileURLWithPath: spec.path))
    guard
      let sourceAudio = asset.tracks(withMediaType: .audio).first,
      let compositionAudio = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )
    else { return nil }

    let scale: CMTimeScale = 44100
    let start = spec.trimStartSeconds ?? 0
    let end = spec.trimEndSeconds ?? CMTimeGetSeconds(asset.duration)
    let sourceRange = CMTimeRange(
      start: CMTime(seconds: start, preferredTimescale: scale),
      duration: CMTime(seconds: max(0, end - start), preferredTimescale: scale)
    )
    func insertPiece(sourceStart: Double, sourceEnd: Double, outputStart: Double, outputDuration: Double) throws {
      let available = min(sourceEnd, end, CMTimeGetSeconds(asset.duration)) - sourceStart
      guard available > 0, outputDuration > 0, outputStart < durationSeconds else { return }
      let rate = (sourceEnd - sourceStart) / outputDuration
      let length = min(available / rate, durationSeconds - outputStart)
      let range = CMTimeRange(start: CMTime(seconds: sourceStart, preferredTimescale: scale),
        duration: CMTime(seconds: length * rate, preferredTimescale: scale))
      let outputAt = CMTime(seconds: outputStart, preferredTimescale: scale)
      try compositionAudio.insertTimeRange(range, of: sourceAudio, at: outputAt)
      if rate != 1 {
        compositionAudio.scaleTimeRange(CMTimeRange(start: outputAt, duration: range.duration),
          toDuration: CMTime(seconds: length, preferredTimescale: scale))
      }
    }
    if spec.sourceTimeMap.count >= 2 && spec.timeMapFps > 0 {
      for index in 0..<(spec.sourceTimeMap.count - 1) {
        try insertPiece(sourceStart: start + spec.sourceTimeMap[index],
          sourceEnd: start + spec.sourceTimeMap[index + 1],
          outputStart: at.seconds + Double(index) / spec.timeMapFps, outputDuration: 1 / spec.timeMapFps)
      }
    } else if spec.tempo > 0 && sourceRange.duration.seconds > 0 {
      let pieceDuration = sourceRange.duration.seconds / spec.tempo
      var cursor = at.seconds
      repeat {
        try insertPiece(sourceStart: start, sourceEnd: end, outputStart: cursor, outputDuration: pieceDuration)
        cursor += pieceDuration
      } while spec.loop && cursor < durationSeconds
    }
    let gain = spec.volume * masterVolume
    let params = AVMutableAudioMixInputParameters(track: compositionAudio)
    func envelope(_ seconds: Double) -> Float {
      let local = seconds - at.seconds
      var value: Float = 1
      let points = spec.volumeEnvelope
      if let first = points.first, let last = points.last {
        if local <= first.0 { value = first.1 }
        else if local >= last.0 { value = last.1 }
        else {
          for i in 1..<points.count where local <= points[i].0 {
            let a = points[i - 1], b = points[i]
            value = a.1 + (b.1 - a.1) * Float((local - a.0) / (b.0 - a.0))
            break
          }
        }
      }
      if let fadeIn = spec.fadeInSeconds, fadeIn > 0 { value *= Float(min(1, max(0, local / fadeIn))) }
      if let fadeOut = spec.fadeOutSeconds, fadeOut > 0 { value *= Float(min(1, max(0, 1 - (seconds - spec.fadeOutStartSeconds) / fadeOut))) }
      return gain * value
    }
    // The product of fade and automation ramps can be quadratic. Sample at
    // audio-block resolution, including authored breakpoints, to retain both.
    var times = Set<Double>([at.seconds, durationSeconds])
    for point in spec.volumeEnvelope { times.insert(min(durationSeconds, max(at.seconds, at.seconds + point.0))) }
    if let fadeIn = spec.fadeInSeconds { times.insert(min(durationSeconds, at.seconds + fadeIn)) }
    if let fadeOut = spec.fadeOutSeconds {
      times.insert(min(durationSeconds, max(at.seconds, spec.fadeOutStartSeconds)))
      times.insert(min(durationSeconds, max(at.seconds, spec.fadeOutStartSeconds + fadeOut)))
    }
    if !spec.volumeEnvelope.isEmpty && (spec.fadeInSeconds != nil || spec.fadeOutSeconds != nil) {
      var cursor = at.seconds
      while cursor < durationSeconds { times.insert(cursor); cursor += 1.0 / 200 }
    }
    let ordered = times.filter { $0 >= at.seconds && $0 <= durationSeconds }.sorted()
    params.setVolume(envelope(at.seconds), at: at)
    for i in 1..<ordered.count {
      let a = ordered[i - 1], b = ordered[i]
      params.setVolumeRamp(fromStartVolume: envelope(a), toEndVolume: envelope(b),
        timeRange: CMTimeRange(start: CMTime(seconds: a, preferredTimescale: scale), duration: CMTime(seconds: b-a, preferredTimescale: scale)))
    }
    return params
  }

}
