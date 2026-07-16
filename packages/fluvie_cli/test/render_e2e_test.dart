@Tags(['ffmpeg'])
@Timeout(Duration(minutes: 15))
library;

// End-to-end acceptance (WI-33): the real two-process pipeline. Needs
// flutter, ffmpeg (>= 6.0) and ffprobe on PATH; CI-optional via the ffmpeg
// tag. The capture step compiles and runs the example test harness, so give
// it minutes, not seconds.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const String _outPath = '/tmp/fluvie_demo_test/demo.mp4';
const String _multiScenePath = '/tmp/fluvie_demo_test/multi_scene.mp4';
const String _lesson04Path = '/tmp/fluvie_demo_test/04_scenes_and_transitions.mp4';
const String _lesson05Path = '/tmp/fluvie_demo_test/05_images_and_clips.mp4';
const String _lesson12Path = '/tmp/fluvie_demo_test/12_the_kitchen_sink.mp4';
const String _gifPath = '/tmp/fluvie_demo_test/demo.gif';
const String _sequenceDir = '/tmp/fluvie_demo_test/frames';
const String _fileTargetProject = '/tmp/fluvie_demo_test/file_target';

/// The whole of a single-file Fluvie project: one composition, no registry.
const String _fileComposition = '''
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Video build() => Video(
  width: 64,
  height: 64,
  fps: 12,
  scenes: [
    Scene(
      duration: Time.frames(6),
      background: Background.color(const Color(0xFF102030)),
      children: const [Text('hi', style: TextStyle(color: Colors.white, fontSize: 12))],
    ),
  ],
);
''';

Future<ProcessResult> _renderKey(String key, String outPath, List<String> extra) =>
    Process.run('dart', [
      'run',
      'bin/fluvie.dart',
      'render',
      key,
      '--out',
      outPath,
      '--verbose',
      ...extra,
    ]);

/// Renders a composition FILE (the single-file flow), rather than a registry key.
Future<ProcessResult> _renderFile(String path, String outPath, List<String> extra) =>
    Process.run('dart', [
      'run',
      'bin/fluvie.dart',
      'render',
      path,
      '--out',
      outPath,
      '--verbose',
      ...extra,
    ]);

Future<ProcessResult> _render(List<String> extra) => _renderKey('demo', _outPath, extra);

String _combined(ProcessResult result) => '${result.stdout}\n${result.stderr}';

/// The parsed ffprobe stream/format report for [path].
Future<Map<String, Object?>> _probe(String path) async {
  final probe = await Process.run('ffprobe', [
    '-v',
    'error',
    '-print_format',
    'json',
    '-show_streams',
    '-show_format',
    path,
  ]);
  expect(probe.exitCode, 0, reason: probe.stderr as String);
  return jsonDecode(probe.stdout as String) as Map<String, Object?>;
}

void main() {
  setUpAll(() async {
    const hint =
        'The ffmpeg-tagged e2e needs flutter, ffmpeg >= 6.0 and ffprobe on '
        'PATH (e.g. `sudo apt install ffmpeg` plus a Flutter SDK).';
    for (final probe in [
      ['flutter', '--version'],
      ['ffmpeg', '-version'],
      ['ffprobe', '-version'],
    ]) {
      final result = await Process.run(probe.first, [probe.last]);
      expect(result.exitCode, 0, reason: '"${probe.join(' ')}" failed. $hint');
    }
    final outDir = Directory('/tmp/fluvie_demo_test');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
  });

  test('fluvie render <file.dart>: the single-file flow, no registry (SINGLE-FILE)', () async {
    // The headline of the single-file CLI: a project is a composition file, an
    // assets/ folder and a pubspec. There is no registry, no committed harness
    // and no app. The CLI stages a harness that statically imports the
    // composition and drives the same capture the keyed path does.
    final project = Directory(_fileTargetProject)..createSync(recursive: true);
    File('${project.path}/pubspec.yaml').writeAsStringSync('''
name: e2e_clip
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  fluvie:
    path: ${Directory.current.parent.path}/fluvie

dev_dependencies:
  flutter_test:
    sdk: flutter
  alchemist: ^0.14.0
''');
    File('${project.path}/lib/example_video.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(_fileComposition);

    final got = await Process.run('flutter', const [
      'pub',
      'get',
    ], workingDirectory: project.path);
    expect(got.exitCode, 0, reason: '${got.stdout}\n${got.stderr}');

    const outPath = '$_fileTargetProject/clip.mp4';
    final result = await _renderFile(
      '$_fileTargetProject/lib/example_video.dart',
      outPath,
      const ['--no-cache'],
    );
    expect(result.exitCode, 0, reason: _combined(result));

    // ffprobe verifies the composition really reached an encoded file.
    final report = await _probe(outPath);
    final stream = (report['streams']! as List<Object?>).single! as Map<String, Object?>;
    expect(stream['codec_name'], 'h264');
    expect(stream['width'], 64);
    expect(stream['height'], 64);
    expect(stream['nb_frames'], '6');

    // The harness is generated per render and never committed, so it cannot
    // drift from the CLI that writes it. It survives the render so `flutter
    // test`'s kernel cache hits on a re-render of the same target.
    final harness = File('$_fileTargetProject/.fluvie/lib_example_video_dart/harness_test.dart');
    expect(harness.existsSync(), isTrue);
    // Imported by its package URI: a relative import would give the same file a
    // second library identity, so its Video would not be the harness's Video.
    expect(
      harness.readAsStringSync(),
      contains("import 'package:e2e_clip/example_video.dart' as target;"),
    );

    // A re-render works against the surviving staging directory.
    final again = await _renderFile(
      '$_fileTargetProject/lib/example_video.dart',
      '$_fileTargetProject/clip2.mp4',
      const ['--no-cache'],
    );
    expect(again.exitCode, 0, reason: _combined(again));
  });

  test('fluvie render demo: encode, probe, cache hits, --no-cache', () async {
    // First run: renders (cold or warm cache) and produces a playable file.
    final first = await _render(const []);
    expect(first.exitCode, 0, reason: _combined(first));
    final output = File(_outPath);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));

    // ffprobe verifies h264 / 320x240 / 48 frames / 1.6 s.
    final report = await _probe(_outPath);
    final streams = report['streams']! as List<Object?>;
    expect(streams, hasLength(1), reason: 'the demo has no audio: one video stream only');
    final stream = streams.single! as Map<String, Object?>;
    expect(stream['codec_name'], 'h264');
    expect(stream['width'], 320);
    expect(stream['height'], 240);
    expect(stream['nb_frames'], '48');
    final format = report['format']! as Map<String, Object?>;
    expect(double.parse(format['duration']! as String), closeTo(1.6, 1e-6));

    // Second run: every frame replays from the shared cache.
    final second = await _render(const []);
    expect(second.exitCode, 0, reason: _combined(second));
    expect(_combined(second), contains('cache hits 48 of 48'));

    // --no-cache forces a full re-capture.
    final noCache = await _render(const ['--no-cache']);
    expect(noCache.exitCode, 0, reason: _combined(noCache));
    expect(_combined(noCache), contains('cache hits 0 of 48'));
  });

  test('fluvie render demo --format gif --poster: gif + poster artifacts (WI-26)', () async {
    final result = await _renderKey('demo', _gifPath, const [
      '--no-cache',
      '--frames',
      '12',
      '--format',
      'gif',
      '--poster',
      '0.2s',
    ]);
    expect(result.exitCode, 0, reason: _combined(result));
    final gif = File(_gifPath);
    expect(gif.existsSync(), isTrue);
    expect(gif.lengthSync(), greaterThan(0));

    // ffprobe confirms it is really a gif.
    final report = await _probe(_gifPath);
    final stream = (report['streams']! as List<Object?>).first! as Map<String, Object?>;
    expect(stream['codec_name'], 'gif');

    // The poster sibling PNG exists.
    final poster = File('/tmp/fluvie_demo_test/demo.poster.png');
    expect(poster.existsSync(), isTrue, reason: 'the --poster sibling PNG must be written');
    final posterReport = await _probe(poster.path);
    final posterStream = (posterReport['streams']! as List<Object?>).first! as Map<String, Object?>;
    expect(posterStream['codec_name'], 'png');
  });

  test('fluvie render demo --format imageSequence: N stills land in --out dir', () async {
    // The image-sequence export writes the `image2` pattern `frame_%06d.png`,
    // which ffmpeg expands into one still per frame. The CLI must treat --out as
    // a target directory and collect every produced PNG into it (the defect: the
    // single-file completion path could never see the literal pattern on disk).
    const stills = 8;
    final result = await _renderKey('demo', _sequenceDir, const [
      '--no-cache',
      '--frames',
      '$stills',
      '--format',
      'imageSequence',
    ]);
    expect(result.exitCode, 0, reason: _combined(result));

    final dir = Directory(_sequenceDir);
    expect(dir.existsSync(), isTrue, reason: '--out is treated as a target directory');
    final pngs =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .map((f) => f.uri.pathSegments.last)
            .toList()
          ..sort();
    expect(pngs, hasLength(stills), reason: 'one still per captured frame');
    // The `image2` muxer is 1-based, so the run starts at frame_000001; assert
    // the zero-padded `frame_NNNNNN.png` shape and a contiguous index run
    // rather than pinning the start index.
    final pattern = RegExp(r'^frame_(\d{6})\.png$');
    final indices = [
      for (final name in pngs) int.parse(pattern.firstMatch(name)!.group(1)!),
    ];
    expect(indices, List.generate(stills, (i) => indices.first + i));

    // ffprobe confirms each landed file is a real PNG of the right size.
    final report = await _probe('$_sequenceDir/${pngs.first}');
    final stream = (report['streams']! as List<Object?>).first! as Map<String, Object?>;
    expect(stream['codec_name'], 'png');
    expect(stream['width'], 320);
    expect(stream['height'], 240);
  });

  test('fluvie list prints the demo key (WI-26)', () async {
    final result = await Process.run('dart', const ['run', 'bin/fluvie.dart', 'list']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout as String, contains('demo'));
  });

  test('fluvie render multi_scene: the 3-scene Video encodes 84 frames (WI-31)', () async {
    final result = await _renderKey('multi_scene', _multiScenePath, const ['--no-cache']);
    expect(result.exitCode, 0, reason: _combined(result));
    final output = File(_multiScenePath);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));

    // ffprobe verifies h264 / 320x240 / 84 frames / 2.8 s — the gated scene
    // stack (24 + 36 + 24) really reaches the encoded file.
    final report = await _probe(_multiScenePath);
    final streams = report['streams']! as List<Object?>;
    expect(streams, hasLength(1), reason: 'audio is inert data until Phase 13: video stream only');
    final stream = streams.single! as Map<String, Object?>;
    expect(stream['codec_name'], 'h264');
    expect(stream['width'], 320);
    expect(stream['height'], 240);
    expect(stream['nb_frames'], '84');
    final format = report['format']! as Map<String, Object?>;
    expect(double.parse(format['duration']! as String), closeTo(2.8, 1e-6));
  });

  test('fluvie render 04_scenes_and_transitions: the overlap shortens the total (WI-21)', () async {
    final result = await _renderKey('04_scenes_and_transitions', _lesson04Path, const [
      '--no-cache',
    ]);
    expect(result.exitCode, 0, reason: _combined(result));
    final output = File(_lesson04Path);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));

    // ffprobe verifies h264 / 1080x1080 / 255 frames / 8.5 s. Three 90-frame
    // scenes sum to 270; the overlapping crossFade (15 frames) shortens it to
    // 255, while the sequential wipe leaves the total alone — the D2 overlap
    // math proven end-to-end through the encoded file.
    final report = await _probe(_lesson04Path);
    final streams = report['streams']! as List<Object?>;
    expect(streams, hasLength(1), reason: 'audio is inert data until Phase 13: video stream only');
    final stream = streams.single! as Map<String, Object?>;
    expect(stream['codec_name'], 'h264');
    expect(stream['width'], 1080);
    expect(stream['height'], 1080);
    expect(stream['nb_frames'], '255');
    final format = report['format']! as Map<String, Object?>;
    expect(double.parse(format['duration']! as String), closeTo(8.5, 1e-6));
  });

  test('fluvie render 05_images_and_clips: the media path renders end-to-end (WI-25)', () async {
    // The media lesson exercises the full pre-resolution pipeline: the harness
    // decodes the swatch fixture and probes/extracts clip_1s.mp4 with real
    // ffmpeg before frame 0. A 30-frame draft keeps the render brief while still
    // proving images and clips reach the encoded file.
    final result = await _renderKey('05_images_and_clips', _lesson05Path, const [
      '--no-cache',
      '--frames',
      '30',
    ]);
    expect(result.exitCode, 0, reason: _combined(result));
    final output = File(_lesson05Path);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));

    // ffprobe verifies h264 / 1080x1080 / 30 captured frames / 1.0 s.
    final report = await _probe(_lesson05Path);
    final streams = report['streams']! as List<Object?>;
    expect(streams, hasLength(1), reason: 'audio is inert data until Phase 13: video stream only');
    final stream = streams.single! as Map<String, Object?>;
    expect(stream['codec_name'], 'h264');
    expect(stream['width'], 1080);
    expect(stream['height'], 1080);
    expect(stream['nb_frames'], '30');
    final format = report['format']! as Map<String, Object?>;
    expect(double.parse(format['duration']! as String), closeTo(1.0, 1e-6));
  });

  test('fluvie render 12_the_kitchen_sink: the music bed reaches the file (AUDMIX-WIRE)', () async {
    // The audio-mix proof: lesson 12 declares Audio.music over the committed WAV.
    // Before the wiring fix the capture path saw no stager and emitted `-an`, so
    // the file was silent. Now the harness stages the mix, so ffprobe finds an
    // aac audio stream beside the video. A 30-frame draft keeps the render brief
    // while still proving the encoder mixed the track into the output.
    final result = await _renderKey('12_the_kitchen_sink', _lesson12Path, const [
      '--no-cache',
      '--frames',
      '30',
    ]);
    expect(result.exitCode, 0, reason: _combined(result));
    final output = File(_lesson12Path);
    expect(output.existsSync(), isTrue);
    expect(output.lengthSync(), greaterThan(0));

    // ffprobe finds two streams: the h264 video and the mixed aac audio.
    final report = await _probe(_lesson12Path);
    final streams = (report['streams']! as List<Object?>).cast<Map<String, Object?>>();
    final codecs = streams.map((s) => s['codec_name']).toSet();
    expect(codecs, contains('h264'));
    expect(
      codecs,
      contains('aac'),
      reason: 'the staged Audio.music must reach the file as an aac stream, not -an',
    );
    final audio = streams.firstWhere((s) => s['codec_type'] == 'audio');
    expect(audio['codec_name'], 'aac');
  });
}
