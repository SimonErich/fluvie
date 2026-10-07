import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/editor/media_probe_io.dart';

final class _Probe extends Fake implements Process {
  _Probe(this.json, {this.code = 0});
  final String json;
  final int? code;
  final completed = Completer<int>();
  bool killed = false;
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(json));
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => code == null ? completed.future : Future.value(code);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!completed.isCompleted) completed.complete(-9);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('still image metadata reads bytes and file paths without invoking the video probe', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
    );
    final directory = await Directory.systemTemp.createTemp('fluvie-probe-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(png);
    for (final path in [null, file.path]) {
      final result = await probeImportedMedia(
        path: path,
        bytes: path == null ? png : null,
        video: false,
        audio: false,
      );
      expect(result.width, 1);
      expect(result.height, 1);
      expect(result.duration, isNull);
    }
    final absent = await probeImportedMedia(path: null, bytes: null, video: false, audio: false);
    expect(absent.width, isNull);
    final invalid = await probeImportedMedia(
      path: null,
      bytes: Uint8List.fromList([1, 2, 3]),
      video: false,
      audio: false,
    );
    expect(invalid.width, isNull);
  });
  test(
    'timed import preserves probe metadata and fails closed on unavailable or stalled processes',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie-probe-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/clip.mp4');
      await file.writeAsBytes([1]);
      var process = _Probe(
        jsonEncode({
          'streams': [
            {'codec_type': 'video', 'width': 1920, 'height': 1080, 'avg_frame_rate': '30000/1001'},
            {'codec_type': 'audio', 'channels': 2},
          ],
          'format': {'duration': '2.5'},
        }),
      );
      Future<Process> start(String name, List<String> args) async {
        expect(name, 'ffprobe');
        expect(
          args,
          containsAllInOrder(['-show_streams', '-show_format', '-of', 'json', file.path]),
        );
        return process;
      }

      final video = await probeImportedMedia(
        path: file.path,
        bytes: null,
        video: true,
        audio: false,
        startProcess: start,
      );
      expect(video.fps, closeTo(29.97002997, .000001));
      expect(video.width, 1920);
      expect(video.channels, 2);
      final audio = await probeImportedMedia(
        path: file.path,
        bytes: null,
        video: false,
        audio: true,
        startProcess: start,
      );
      expect(audio.duration, '2.5s');
      expect(audio.fps, 1000);
      expect(audio.width, isNull);
      process = _Probe('invalid json');
      expect(
        (await probeImportedMedia(
          path: file.path,
          bytes: null,
          video: true,
          audio: false,
          startProcess: start,
        )).fps,
        isNull,
      );
      process = _Probe('', code: 1);
      expect(
        (await probeImportedMedia(
          path: file.path,
          bytes: null,
          video: true,
          audio: false,
          startProcess: start,
        )).fps,
        isNull,
      );
      process = _Probe('', code: null);
      final timeout = await probeImportedMedia(
        path: file.path,
        bytes: null,
        video: true,
        audio: false,
        startProcess: start,
        timeout: const Duration(milliseconds: 1),
      );
      expect(timeout.duration, isNull);
      expect(process.killed, isTrue);
      final missing = await probeImportedMedia(
        path: '${directory.path}/missing.mp4',
        bytes: null,
        video: true,
        audio: false,
        startProcess: (_, _) => throw StateError('must not start'),
      );
      expect(missing.fps, isNull);
    },
  );
}
