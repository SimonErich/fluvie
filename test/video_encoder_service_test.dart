import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/encoding/video_encoder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> capturedArgs;
  late FakeProcess fakeProcess;

  Future<Process> fakeFactory(String executable, List<String> args) async {
    expect(executable, equals('ffmpeg'));
    capturedArgs = args;
    fakeProcess = FakeProcess();
    return fakeProcess;
  }

  RenderConfig buildConfig({EncodingConfig? encoding}) {
    return RenderConfig(
      timeline: TimelineConfig(
        fps: 30,
        durationInFrames: 60,
        width: 1080,
        height: 1080,
      ),
      sequences: const [],
      encoding: encoding,
    );
  }

  void expectFlagValue(String flag, String expected) {
    final index = capturedArgs.indexOf(flag);
    expect(index, isNonNegative, reason: 'Flag $flag missing in $capturedArgs');
    expect(capturedArgs[index + 1], expected);
  }

  test(
    'uses default medium quality when no encoding settings provided',
    () async {
      final service = VideoEncoderService(
        processFactory: fakeFactory,
        tempDirProvider: () async =>
            Directory.systemTemp.createTemp('fluvie_test'),
      );

      final session = await service.startEncoding(
        config: buildConfig(),
        outputFileName: 'test.mp4',
      );
      fakeProcess.complete(0);
      await session.completed;

      expectFlagValue('-crf', '23');
      expectFlagValue('-preset', 'medium');
    },
  );

  test('respects quality overrides', () async {
    final service = VideoEncoderService(
      processFactory: fakeFactory,
      tempDirProvider: () async =>
          Directory.systemTemp.createTemp('fluvie_test'),
    );

    final session = await service.startEncoding(
      config: buildConfig(
        encoding: const EncodingConfig(
          quality: RenderQuality.high,
          crfOverride: 10,
          presetOverride: 'faster',
        ),
      ),
      outputFileName: 'test.mp4',
    );
    fakeProcess.complete(0);
    await session.completed;

    expectFlagValue('-crf', '10');
    expectFlagValue('-preset', 'faster');
  });

  test('propagates ffmpeg failures', () async {
    final service = VideoEncoderService(
      processFactory: fakeFactory,
      tempDirProvider: () async =>
          Directory.systemTemp.createTemp('fluvie_test'),
    );

    final session = await service.startEncoding(
      config: buildConfig(),
      outputFileName: 'test.mp4',
    );

    fakeProcess.emitStderr('boom');
    fakeProcess.complete(1);

    await expectLater(
      session.completed,
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('boom'),
        ),
      ),
    );
  });
}

class FakeProcess implements Process {
  final _stdinController = StreamController<List<int>>();
  final _stdoutController = StreamController<List<int>>.broadcast();
  final _stderrController = StreamController<List<int>>.broadcast();
  final _exitCodeCompleter = Completer<int>();
  bool _killed = false;

  IOSink? _stdin;

  FakeProcess() {
    _stdin = IOSink(_stdinController.sink);
  }

  void emitStderr(String message) {
    _stderrController.add(utf8.encode(message));
  }

  void complete(int code) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
    _stdinController.close();
    _stdoutController.close();
    _stderrController.close();
  }

  @override
  IOSink get stdin => _stdin!;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _killed = true;
    complete(-signal.hashCode);
    return true;
  }

  bool get killed => _killed;

  @override
  int get pid => 0;
}
