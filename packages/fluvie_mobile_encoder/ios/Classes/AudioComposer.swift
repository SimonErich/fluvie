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

  init(videoURL: URL, tracks: [AudioTrackSpec], masterVolume: Float) {
    self.videoURL = videoURL
    self.tracks = tracks
    self.masterVolume = masterVolume
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
      at: .zero
    )

    let durationSeconds = CMTimeGetSeconds(videoAsset.duration)
    var parameters: [AVMutableAudioMixInputParameters] = []
    for spec in tracks {
      if let params = try insert(spec, into: composition, fillTo: durationSeconds) {
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
    let at = CMTime(value: CMTimeValue(spec.delayMs), timescale: 1000)
    if spec.loop && sourceRange.duration.seconds > 0 {
      try tile(sourceRange, of: sourceAudio, into: compositionAudio, from: at, fillTo: durationSeconds)
    } else {
      try compositionAudio.insertTimeRange(sourceRange, of: sourceAudio, at: at)
    }

    let gain = spec.volume * masterVolume
    let params = AVMutableAudioMixInputParameters(track: compositionAudio)
    params.setVolume(gain, at: at)
    if let fadeIn = spec.fadeInSeconds {
      params.setVolumeRamp(
        fromStartVolume: 0,
        toEndVolume: gain,
        timeRange: CMTimeRange(start: at, duration: CMTime(seconds: fadeIn, preferredTimescale: scale))
      )
    }
    if let fadeOut = spec.fadeOutSeconds {
      let fadeStart = at + CMTime(seconds: spec.fadeOutStartSeconds, preferredTimescale: scale)
      params.setVolumeRamp(
        fromStartVolume: gain,
        toEndVolume: 0,
        timeRange: CMTimeRange(start: fadeStart, duration: CMTime(seconds: fadeOut, preferredTimescale: scale))
      )
    }
    return params
  }

  /// Repeats [sourceRange] back to back into [track] from [start] until the
  /// composition reaches [durationSeconds], clamping the final repeat. This is
  /// how a looping bed fills a video longer than the source.
  private func tile(
    _ sourceRange: CMTimeRange,
    of sourceAudio: AVAssetTrack,
    into track: AVMutableCompositionTrack,
    from start: CMTime,
    fillTo durationSeconds: Double
  ) throws {
    let end = CMTime(seconds: durationSeconds, preferredTimescale: 44100)
    let piece = sourceRange.duration
    // Skip a final sliver shorter than one sample: inserting a sub-sample range
    // is a no-op at best and an AVFoundation glitch at worst.
    let minimal = CMTime(value: 1, timescale: 44100)
    var cursor = start
    while cursor < end {
      let remaining = end - cursor
      if remaining < minimal { break }
      let thisDuration = remaining < piece ? remaining : piece
      try track.insertTimeRange(
        CMTimeRange(start: sourceRange.start, duration: thisDuration),
        of: sourceAudio,
        at: cursor
      )
      cursor = cursor + thisDuration
    }
  }
}
