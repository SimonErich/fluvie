/// Package-addressed paths to the Kitten Mitten sample media bundled in
/// `kitten_kit`.
///
/// Every Fluvie example app depends on `kitten_kit`, so these `packages/...`
/// keys resolve through the shared asset bundle on every render path (CLI
/// capture, in-browser, on-device, and server).
abstract final class KittenAssets {
  /// A short looping kitten jingle (a deterministic WAV the encoder can mix).
  static const String jingle = 'packages/kitten_kit/assets/audio/beat_loop.wav';

  /// The jingle reused as a one-shot sound effect (avoids a second binary).
  static const String meowSfx = jingle;

  /// A one-second sample clip for picture-in-picture and B-roll.
  static const String clip = 'packages/kitten_kit/assets/fixtures/clip_1s.mp4';

  /// A small committed image, used to demonstrate `Image.asset`.
  static const String photo = 'packages/kitten_kit/assets/fixtures/swatch.png';

  /// A SubRip caption track of kitten one-liners.
  static const String captions = 'packages/kitten_kit/assets/captions/kitten.srt';
}
