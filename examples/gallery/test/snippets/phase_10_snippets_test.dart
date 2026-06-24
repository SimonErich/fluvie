// The Phase 10 doc snippets compile and build (WI-40): the audio-and-captions
// page pulls these via code-excerpt markers, so a failing build here means a
// doc would ship dead code.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_10_snippets.dart';

void main() {
  test('the audio constructors build two tracks', () {
    final tracks = audioConstructors('assets/audio/beat.wav');
    expect(tracks, hasLength(2));
    expect(tracks.first.isSfx, isFalse);
    expect(tracks.last.isSfx, isTrue);
  });

  test('the caption constructors build three sources', () {
    final captions = captionConstructors('cues.srt', const [
      CaptionWord('hi', at: Time.zero),
    ]);
    expect(captions, hasLength(3));
  });

  test('the caption-style and position menus list the presets', () {
    expect(captionStyles(), hasLength(3));
    expect(captionPositions(), hasLength(4));
  });
}
