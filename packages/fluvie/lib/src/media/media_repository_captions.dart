part of 'media_repository.dart';

/// The caption resolution path of [MediaRepository]: read the SRT/VTT file
/// through the byte loader and parse it once before frame 0, or turn inline
/// words into cues with no IO.
///
/// Kept in its own part so the main file stays within the line budget while the
/// `@override` stubs there delegate here with implicit `this`.
extension _CaptionResolution on MediaRepository {
  /// Resolves [source] to its parsed cues, skipping a source already parsed.
  Future<void> _resolveCaptions(CaptionSource source) async {
    if (_captionCues.containsKey(source)) return;
    _captionCues[source] = await _parseCaptions(source);
  }

  /// Reads and parses one caption source into cues: an SRT/VTT file is loaded
  /// through the byte loader (the asset/file path read as a bundled asset) and
  /// parsed by the in-house parser; an inline source maps its words to cues.
  Future<List<CaptionCue>> _parseCaptions(CaptionSource source) async {
    switch (source) {
      case SrtCaptionSource(:final path):
        return parseSrt(await _captionText(path));
      case VttCaptionSource(:final path):
        return parseVtt(await _captionText(path));
      case InlineCaptionSource(:final words):
        return _cuesFromWords(words);
    }
  }

  /// Reads the caption file at [path] as UTF-8 text through the byte loader.
  Future<String> _captionText(String path) async {
    final bytes = await loader.load(MediaSource.asset(path));
    return utf8.decode(bytes);
  }

  /// One single-word cue per inline word: the word spans from its own start to
  /// the next word's start (or a one-second tail for the last word), and carries
  /// its own word-level timing for word-pop and karaoke.
  List<CaptionCue> _cuesFromWords(List<CaptionWord> words) => [
    for (var i = 0; i < words.length; i++)
      CaptionCue(
        words[i].text,
        start: words[i].at,
        end: i + 1 < words.length ? words[i + 1].at : words[i].at + const Time.seconds(1),
        words: [CaptionCueWord(words[i].text, at: words[i].at)],
      ),
  ];
}
