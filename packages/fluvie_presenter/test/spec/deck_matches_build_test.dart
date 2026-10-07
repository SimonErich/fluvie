// Two builders turn one spec into a Video: `VideoSpec.build` for a render and
// `deckFromSpec` for a presentation. Every video-level field they hand the
// Video has to agree, or a deck presents something other than what it renders.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// A deck exercising every video-level field: a poster, an export block,
/// motion defaults, a transition, two audio tracks (one on a muted lane), and
/// two overlays.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'poster': '15f',
  'export': {'mode': 'mp4', 'quality': 'high'},
  'motionDefaults': {'duration': '12f'},
  'transition': {'kind': 'crossFade', 'duration': '10f'},
  'lanes': [
    {'id': 'a1', 'kind': 'audio'},
    {'id': 'a2', 'kind': 'audio', 'muted': true},
  ],
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/bed.mp3'},
      'lane': 'a1',
    },
    {
      'kind': 'music',
      'source': {'kind': 'asset', 'value': 'audio/silenced.mp3'},
      'lane': 'a2',
    },
  ],
  'overlays': [
    {'id': 'ov-logo', 'type': 'Text', 'text': 'logo'},
    {
      'id': 'ov-ticker',
      'type': 'Text',
      'text': 'live',
      'show': {'from': '10f', 'to': '40f'},
    },
  ],
  'scenes': <Object?>[
    {
      'duration': '60f',
      'children': [
        {'id': 'el-a', 'type': 'Text', 'text': 'one'},
      ],
    },
    {
      'duration': '60f',
      'children': [
        {'id': 'el-b', 'type': 'Text', 'text': 'two'},
      ],
    },
  ],
};

void main() {
  late VideoSpec spec;
  late Video rendered;
  late Video presented;

  setUp(() {
    spec = VideoSpec.fromJson(_deck());
    rendered = spec.build();
    presented = deckFromSpec(spec);
  });

  test('the size, fps, poster and export agree', () {
    expect(presented.width, rendered.width);
    expect(presented.height, rendered.height);
    expect(presented.fps, rendered.fps);
    expect(presented.poster, rendered.poster);
    expect(presented.export?.mode, rendered.export?.mode);
    expect(presented.export?.quality, rendered.export?.quality);
  });

  test('the motion defaults and the transition agree', () {
    expect(presented.motionDefaults, rendered.motionDefaults);
    expect(presented.transition?.kind, rendered.transition?.kind);
  });

  test('the audio agrees, muted lanes included', () {
    // The mute is a rule of the document, not of the renderer: a deck that
    // played a silenced bed would sound different from its own export.
    expect(presented.audio, hasLength(rendered.audio.length));
    expect(rendered.audio, hasLength(1));
  });

  test('the overlays agree', () {
    expect(presented.overlays, hasLength(rendered.overlays.length));
    expect(presented.overlays, hasLength(2));
  });

  test('the scene count and the video length agree', () {
    expect(presented.scenes, hasLength(rendered.scenes.length));
    expect(presented.totalFrames, rendered.totalFrames);
  });

  test('a deck with none of the optional parts still agrees', () {
    final plain = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 30,
      'scenes': [
        {'duration': '30f'},
      ],
    });

    expect(deckFromSpec(plain).overlays, plain.build().overlays);
    expect(deckFromSpec(plain).audio, plain.build().audio);
  });
}
