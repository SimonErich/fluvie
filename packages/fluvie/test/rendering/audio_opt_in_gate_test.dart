// The one audio-drop policy every renderer shares: audio is opt-in on-device
// and in-browser, so a Video that declares audio while the opt-in is off
// yields no mix and warns once (suppressibly). The platform label is the only
// thing that differs between renderers.

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

Video _withAudio() => Video(
  width: 32,
  height: 32,
  audio: const [Audio.music('beat.wav')],
  scenes: const [
    Scene(duration: Time.frames(2), children: [Text('hi')]),
  ],
);

Video _silent() => Video(
  width: 32,
  height: 32,
  scenes: const [
    Scene(duration: Time.frames(2), children: [Text('hi')]),
  ],
);

void main() {
  group('gateOptInAudio', () {
    test('a non-Video composition yields no mix, silently', () {
      final warnings = <String>[];
      final mix = gateOptInAudio(
        composition: const SizedBox(),
        encode: true,
        warn: true,
        fps: 30,
        frameCount: 2,
        warnSink: warnings.add,
        platformLabel: 'on-device',
      );
      expect(mix, isNull);
      expect(warnings, isEmpty);
    });

    test('an audio-less Video yields no mix, silently', () {
      final warnings = <String>[];
      final mix = gateOptInAudio(
        composition: _silent(),
        encode: true,
        warn: true,
        fps: 30,
        frameCount: 2,
        warnSink: warnings.add,
        platformLabel: 'on-device',
      );
      expect(mix, isNull);
      expect(warnings, isEmpty);
    });

    test('declared audio with the opt-in off warns once with the platform label', () {
      final warnings = <String>[];
      final mix = gateOptInAudio(
        composition: _withAudio(),
        encode: false,
        warn: true,
        fps: 30,
        frameCount: 2,
        warnSink: warnings.add,
        platformLabel: 'in-browser',
      );
      expect(mix, isNull);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('in-browser'));
      expect(warnings.single, contains('audio: true'));
    });

    test('warn false silences the drop warning', () {
      final warnings = <String>[];
      final mix = gateOptInAudio(
        composition: _withAudio(),
        encode: false,
        warn: false,
        fps: 30,
        frameCount: 2,
        warnSink: warnings.add,
        platformLabel: 'on-device',
      );
      expect(mix, isNull);
      expect(warnings, isEmpty);
    });

    test('a non-MP4 export drops the mix with its own warning', () {
      final warnings = <String>[];
      final mix = gateOptInAudio(
        composition: _withAudio(),
        encode: true,
        warn: true,
        export: const Export.gif(),
        fps: 30,
        frameCount: 2,
        warnSink: warnings.add,
        platformLabel: 'in-browser',
      );
      expect(mix, isNull);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('gif'));
    });

    test('the opt-in on yields the resolved mix', () {
      final warnings = <String>[];
      final mix = gateOptInAudio(
        composition: _withAudio(),
        encode: true,
        warn: true,
        fps: 30,
        frameCount: 2,
        warnSink: warnings.add,
        platformLabel: 'on-device',
      );
      expect(mix, isNotNull);
      expect(mix!.tracks, hasLength(1));
      expect(warnings, isEmpty);
    });
  });
}
