import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/src/audio/encoding/audio_tempo_filter.dart';

void main() {
  test('integrated audio source clock interpolates and holds both window boundaries', () {
    final map = const AudioTimeMap(fps: 2, sourceSeconds: [0, 0.25, 1.25, 2])..validate();
    expect(map.durationSeconds, 1.5);
    expect(map.sourceSecondsAt(-1), 0);
    expect(map.sourceSecondsAt(0.25), 0.125);
    expect(map.sourceSecondsAt(0.75), 0.75);
    expect(map.sourceSecondsAt(1.25), 1.625);
    expect(map.sourceSecondsAt(1.5), 2);
    expect(map.sourceSecondsAt(10), 2);
  });

  test('malformed source clocks fail before generating a backend command', () {
    const invalid = [
      AudioTimeMap(fps: 0, sourceSeconds: [0, 1]),
      AudioTimeMap(fps: 30, sourceSeconds: []),
      AudioTimeMap(fps: 30, sourceSeconds: [0]),
      AudioTimeMap(fps: 30, sourceSeconds: [1, 2]),
      AudioTimeMap(fps: 30, sourceSeconds: [0, 0]),
      AudioTimeMap(fps: 30, sourceSeconds: [0, 1, 0.5]),
      AudioTimeMap(fps: 30, sourceSeconds: [0, double.infinity]),
      AudioTimeMap(fps: 30, sourceSeconds: [0, double.nan]),
    ];
    for (final map in invalid) {
      expect(() => audioTimeMapFilters(map, 0), throwsArgumentError);
    }
  });

  test('extreme ramp rates split into valid persistent stages on the source clock', () {
    const map = AudioTimeMap(fps: 2, sourceSeconds: [0, 0.125, 0.25, 2.25, 2.5]);
    final filters = audioTimeMapFilters(map, 3);
    // Rates are 0.25, 0.25, 4 and 0.5. Two persistent 0.5..2 stages
    // can represent all four without restarting audio at every output frame.
    final stages = filters.where((filter) => filter.startsWith('atempo@')).toList();
    expect(stages, ['atempo@ramp_3_0=0.5', 'atempo@ramp_3_1=0.5']);
    final commands = filters.singleWhere((filter) => filter.startsWith('asendcmd='));
    expect(commands, contains('0.25 atempo@ramp_3_0 tempo 2,atempo@ramp_3_1 tempo 2'));
    expect(commands, isNot(contains('0.125 ')), reason: 'Unchanged adjacent rates need no command');
    final factors = RegExp(
      '2.25 atempo@ramp_3_0 tempo ([0-9.]+),atempo@ramp_3_1 tempo ([0-9.]+)',
    ).firstMatch(commands)!;
    expect(double.parse(factors[1]!) * double.parse(factors[2]!), closeTo(0.5, 1e-12));
    expect(filters.last, 'atrim=duration=2');
  });

  test('constant source clocks avoid tempo commands and retain exact duration', () {
    final filters = audioTimeMapFilters(const AudioTimeMap(fps: 2, sourceSeconds: [0, 0.5, 1]), 0);
    expect(filters, ['atempo@ramp_0_0=1', 'apad', 'atrim=duration=1']);
  });

  test('Dart-authored audio automation rejects inconsistent stops before encoding', () {
    final invalid = [
      const AudioAutomation(values: [double.nan]),
      const AudioAutomation(values: [0, 1]),
      AudioAutomation(values: const [0, 1], positions: [1.seconds, 0.seconds]),
      AudioAutomation(
        values: const [0, 1],
        positions: [0.seconds, 1.seconds],
        easings: const [Ease.linear, Ease.linear],
      ),
    ];
    for (final automation in invalid) {
      expect(() => automation.resolve(fps: 30, windowFrames: 30), throwsArgumentError);
    }
    final curve = AudioAutomation(values: const [-1, 2], positions: [0.seconds, 1.seconds]);
    final points = curve.resolve(fps: 30, windowFrames: 30);
    for (var frame = 0; frame <= 30; frame++) {
      expect(audioVolumeAt(points, frame / 30), inInclusiveRange(0, 1));
    }
    expect(points.first.value, 0);
    expect(points.last.value, 1);
  });
}
