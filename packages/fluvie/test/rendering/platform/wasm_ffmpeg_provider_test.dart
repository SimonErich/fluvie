import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/rendering/platform/wasm_ffmpeg_provider.dart';
import 'package:fluvie/src/rendering/platform/wasm_runtime.dart';
import 'package:mocktail/mocktail.dart';

class _MockWasmRuntime extends Mock implements WasmRuntime {}

const _args = [
  '-f',
  'rawvideo',
  '-pix_fmt',
  'rgba',
  '-video_size',
  '320x240',
  '-framerate',
  '30',
  '-i',
  'frames.rgba',
  '-c:v',
  'libx264',
  '-an',
  'out.mp4',
];

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(Uint8List(0));
  });

  late _MockWasmRuntime runtime;
  late List<String> readInputNames;
  late Map<String, Uint8List> writtenOutputs;
  final inputBytes = Uint8List.fromList(List<int>.generate(16, (i) => i));
  final outputBytes = Uint8List.fromList(const [9, 9, 9]);
  final sandbox = Directory('unused-on-wasm');

  WasmFfmpegProvider makeProvider() => WasmFfmpegProvider(
    runtime: runtime,
    readInput: (name) async {
      readInputNames.add(name);
      return inputBytes;
    },
    writeOutput: (name, bytes) => writtenOutputs[name] = bytes,
  );

  setUp(() {
    runtime = _MockWasmRuntime();
    readInputNames = [];
    writtenOutputs = {};
    when(runtime.load).thenAnswer((_) async {});
    when(() => runtime.writeFile(any(), any())).thenAnswer((_) async {});
    when(() => runtime.exec(any())).thenAnswer((_) async => 0);
    when(() => runtime.readFile(any())).thenAnswer((_) async => outputBytes);
  });

  group('WasmFfmpegProvider', () {
    test('probeVersion returns null (an embedded runtime has no honest banner)', () async {
      expect(await makeProvider().probeVersion(), isNull);
    });

    test('encode runs load → writeFile → exec → readFile in order', () async {
      await makeProvider().encode(args: _args, sandbox: sandbox);
      verifyInOrder([
        runtime.load,
        () => runtime.writeFile('frames.rgba', inputBytes),
        () => runtime.exec(_args),
        () => runtime.readFile('out.mp4'),
      ]);
    });

    test('load is called exactly once across two encodes', () async {
      final provider = makeProvider();
      await provider.encode(args: _args, sandbox: sandbox);
      await provider.encode(args: _args, sandbox: sandbox);
      verify(runtime.load).called(1);
    });

    test('the exact argument array is forwarded to exec untouched', () async {
      await makeProvider().encode(args: _args, sandbox: sandbox);
      final captured = verify(() => runtime.exec(captureAny())).captured;
      expect(captured, [_args]);
    });

    test('inputs are read through readInput and written into the runtime FS', () async {
      await makeProvider().encode(args: _args, sandbox: sandbox);
      expect(readInputNames, ['frames.rgba']);
      verify(() => runtime.writeFile('frames.rgba', inputBytes)).called(1);
    });

    test('lavfi inputs are generated, not files: nothing is read or written for them', () async {
      const argsWithLavfi = [
        '-f',
        'rawvideo',
        '-i',
        'frames.rgba',
        '-f',
        'lavfi',
        '-t',
        '1',
        '-i',
        'anullsrc=r=48000:cl=stereo',
        '-c:v',
        'libx264',
        'out.mp4',
      ];
      await makeProvider().encode(args: argsWithLavfi, sandbox: sandbox);
      expect(readInputNames, ['frames.rgba']);
      verifyNever(() => runtime.writeFile('anullsrc=r=48000:cl=stereo', any()));
    });

    test('the readFile result is handed to writeOutput under the output name', () async {
      await makeProvider().encode(args: _args, sandbox: sandbox);
      expect(writtenOutputs, {'out.mp4': outputBytes});
    });

    test('a non-zero exec code throws FluvieEncodeException carrying the code', () async {
      when(() => runtime.exec(any())).thenAnswer((_) async => 187);
      await expectLater(
        () => makeProvider().encode(args: _args, sandbox: sandbox),
        throwsA(isA<FluvieEncodeException>().having((e) => e.exitCode, 'exitCode', 187)),
      );
      verifyNever(() => runtime.readFile(any()));
      expect(writtenOutputs, isEmpty);
    });
  });
}
