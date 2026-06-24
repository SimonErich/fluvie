/// The kind of media a generative source produces.
///
/// Drives how a resolved generative asset folds back into the render pipeline:
/// the visual kinds ([image], [video]) resolve to a `MediaSource`, and the audio
/// kinds ([music], [speech], [soundEffect]) resolve to an `AudioSource`.
///
/// `MediaSource` and `AudioSource` are named in prose, not as doc links, because
/// a generation backend lives in a layer above `core`.
enum GenerativeKind {
  /// A still image.
  image,

  /// A video clip, optionally carrying an embedded audio track.
  video,

  /// A music track.
  music,

  /// Spoken-word audio (text to speech).
  speech,

  /// A non-speech sound effect.
  soundEffect;

  /// Whether this kind resolves to an `AudioSource` (music, speech, or a sound
  /// effect).
  bool get isAudio =>
      this == GenerativeKind.music ||
      this == GenerativeKind.speech ||
      this == GenerativeKind.soundEffect;

  /// Whether this kind resolves to a visual `MediaSource` (image or video).
  bool get isVisual => this == GenerativeKind.image || this == GenerativeKind.video;
}
