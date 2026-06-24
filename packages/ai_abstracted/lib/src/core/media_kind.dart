/// The six mediums this package normalizes behind uniform capability contracts.
enum MediaKind {
  /// Plain text completion (returned as UTF-8 bytes).
  text,

  /// A still image.
  image,

  /// A video clip (optionally with an audio track).
  video,

  /// Spoken audio synthesized from text (text-to-speech).
  speech,

  /// A short non-musical sound effect.
  soundEffect,

  /// A musical track.
  music;

  /// Whether this medium produces audio bytes (speech, sound effect, music).
  bool get isAudio =>
      this == MediaKind.speech || this == MediaKind.soundEffect || this == MediaKind.music;

  /// Whether this medium produces visual bytes (image or video).
  bool get isVisual => this == MediaKind.image || this == MediaKind.video;
}
