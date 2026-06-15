import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/aspect.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/stagger_origin.dart';
import 'package:fluvie/src/core/wipe_shape.dart';

// Each helper is an exhaustive switch: adding an enum value without a case
// breaks compilation, which is exactly the guarantee these tests pin down.

String _wipe(WipeShape shape) => switch (shape) {
  WipeShape.circle => 'circle',
  WipeShape.rect => 'rect',
  WipeShape.diagonal => 'diagonal',
};

String _origin(StaggerOrigin origin) => switch (origin) {
  StaggerOrigin.start => 'start',
  StaggerOrigin.center => 'center',
  StaggerOrigin.end => 'end',
  StaggerOrigin.edges => 'edges',
};

String _aspect(Aspect aspect) => switch (aspect) {
  Aspect.reels => 'reels',
  Aspect.square => 'square',
  Aspect.landscape => 'landscape',
  Aspect.portrait45 => 'portrait45',
};

String _band(AudioBand band) => switch (band) {
  AudioBand.bass => 'bass',
  AudioBand.mid => 'mid',
  AudioBand.treble => 'treble',
};

String _phase(AnimationPhase phase) => switch (phase) {
  AnimationPhase.enter => 'enter',
  AnimationPhase.exit => 'exit',
  AnimationPhase.during => 'during',
};

void main() {
  test('WipeShape: exhaustive switch covers every value', () {
    expect(WipeShape.values.map(_wipe), ['circle', 'rect', 'diagonal']);
  });

  test('StaggerOrigin: exhaustive switch covers every value', () {
    expect(StaggerOrigin.values.map(_origin), ['start', 'center', 'end', 'edges']);
  });

  test('Aspect: exhaustive switch covers every value', () {
    expect(Aspect.values.map(_aspect), ['reels', 'square', 'landscape', 'portrait45']);
  });

  test('AudioBand: exhaustive switch covers every value', () {
    expect(AudioBand.values.map(_band), ['bass', 'mid', 'treble']);
  });

  test('AnimationPhase: exhaustive switch covers every value', () {
    expect(AnimationPhase.values.map(_phase), ['enter', 'exit', 'during']);
  });
}
