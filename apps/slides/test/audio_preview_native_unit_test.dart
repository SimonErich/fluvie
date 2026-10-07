import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:slides/editor/audio_preview_platform_io.dart';

Uint8List _pcm() {
  final bytes = Uint8List(12);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < 3; i++) {
    data.setFloat32(i * 4, [0.25, -0.5, 0.75][i], Endian.little);
  }
  return bytes;
}

final class _Process extends Fake implements Process {
  _Process({this.output = const Stream.empty(), this.error = '', this.code = 0, this.onKill});
  final Stream<List<int>> output;
  final String error;
  final int? code;
  final void Function()? onKill;
  final completed = Completer<int>();
  bool killed = false;
  @override
  Stream<List<int>> get stdout => output;
  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(error));
  @override
  Future<int> get exitCode => code == null ? completed.future : Future.value(code);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    onKill?.call();
    if (!completed.isCompleted) completed.complete(-9);
    return true;
  }
}

final class _Resolver extends Fake implements MediaResolver {
  _Resolver(this.path);
  final String path;
  final requests = <AudioSource>[];
  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async => requests.addAll(sources);
  @override
  String materializedAudioPathFor(AudioSource source) => path;
}

final class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native decode stages concurrent memory imports once, preserves samples and cleans files',
    () async {
      final staged = <File>[];
      final platform = createAudioPreviewPlatform(
        startProcess: (binary, args) async {
          expect(binary, 'ffmpeg');
          expect(args, containsAllInOrder(['-ac', '1', '-ar', '22050', '-f', 'f32le']));
          final input = File(args[args.indexOf('-i') + 1]);
          expect(await input.readAsBytes(), [1, 2, 3]);
          staged.add(input);
          return _Process(output: Stream.value(_pcm()));
        },
      );
      final sources = [
        AudioSource.memory(Uint8List.fromList([1, 2, 3]), debugLabel: 'one.wav'),
        AudioSource.memory(Uint8List.fromList([1, 2, 3, 4]), debugLabel: 'two.wav'),
      ];
      final results = await Future.wait([
        platform.decode(sources[0]),
        platform.decode(sources[1], bytes: Uint8List.fromList([1, 2, 3])),
      ]);
      for (final result in results) {
        expect(result.sampleRate, 22050);
        expect(result.samples, [0.25, -0.5, 0.75]);
      }
      expect(staged.map((file) => file.parent.path).toSet(), hasLength(1));
      expect(staged.every((file) => !file.existsSync()), isTrue);
      platform.unlock();
      await platform.dispose();
      expect(staged.first.parent.existsSync(), isFalse);
      await expectLater(platform.decode(sources.first), throwsStateError);
    },
  );

  test('native file, resolver and bundle sources reach the same decoder contract', () async {
    final paths = <String>[];
    final platform = createAudioPreviewPlatform(
      startProcess: (binary, args) async {
        paths.add(args[args.indexOf('-i') + 1]);
        return _Process(output: Stream.value(_pcm()));
      },
    );
    addTearDown(platform.dispose);
    await platform.decode(const AudioSource.file('/already-local.wav'));
    final resolver = _Resolver('/resolved.wav');
    const source = AudioSource.asset('bundled.wav');
    await platform.decode(source, resolver: resolver);
    expect(resolver.requests, [source]);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMessageHandler(
        'flutter/assets',
        (message) async => ByteData.sublistView(Uint8List.fromList([4, 5, 6])),
      );
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    await platform.decode(source);
    expect(paths.take(2), ['/already-local.wav', '/resolved.wav']);
    expect(File(paths.last).existsSync(), isFalse);
  });

  test('native network audio enforces allowed hosts and handles HTTP failures', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = request.uri.path == '/ok' ? 200 : 404;
      request.response.add([1, 2, 3]);
      unawaited(request.response.close());
    });
    final platform = createAudioPreviewPlatform(
      startProcess: (binary, args) async {
        expect(await File(args[args.indexOf('-i') + 1]).readAsBytes(), [1, 2, 3]);
        return _Process(output: Stream.value(_pcm()));
      },
    );
    addTearDown(platform.dispose);
    await HttpOverrides.runWithHttpOverrides(() async {
      final ok = AudioSource.network(Uri.parse('http://127.0.0.1:${server.port}/ok'));
      final missing = AudioSource.network(Uri.parse('http://127.0.0.1:${server.port}/missing'));
      await expectLater(platform.decode(ok), throwsStateError);
      await expectLater(
        platform.decode(
          ok,
          allowlist: const NetworkAllowlist(hosts: {'elsewhere'}, schemes: {'http'}),
        ),
        throwsA(isA<FluvieRenderException>()),
      );
      const allowed = NetworkAllowlist(hosts: {'127.0.0.1'}, schemes: {'http'});
      expect((await platform.decode(ok, allowlist: allowed)).samples.length, 3);
      await expectLater(
        platform.decode(missing, allowlist: allowed),
        throwsA(isA<HttpException>()),
      );
    }, _RealHttp());
  });

  test('native decode failures are actionable and staged sources are deleted', () async {
    String? path;
    final platform = createAudioPreviewPlatform(
      startProcess: (binary, args) async {
        path = args[args.indexOf('-i') + 1];
        return _Process(code: 1, error: 'invalid source');
      },
    );
    addTearDown(platform.dispose);
    await expectLater(
      platform.decode(AudioSource.memory(Uint8List.fromList([1]))),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', contains('invalid source')),
      ),
    );
    expect(File(path!).existsSync(), isFalse);
  });

  test(
    'native playback replacement and stop reap output processes without leaking chunks',
    () async {
      final started = StreamController<_Process>();
      final files = <File>[];
      final platform = createAudioPreviewPlatform(
        startProcess: (binary, args) async {
          expect(binary, 'ffplay');
          expect(args, containsAllInOrder(['-ss', '0.25']));
          files.add(File(args.last));
          final process = _Process(code: null);
          started.add(process);
          return process;
        },
      );
      final queue = StreamIterator(started.stream);
      final first = platform.play(Uint8List.fromList([1, 2]), offsetSeconds: 0.25);
      await queue.moveNext();
      final firstProcess = queue.current;
      final second = platform.play(Uint8List.fromList([3, 4]), offsetSeconds: 0.25);
      await queue.moveNext();
      final secondProcess = queue.current;
      expect(firstProcess.killed, isTrue);
      await first;
      await platform.stop();
      await second;
      expect(secondProcess.killed, isTrue);
      expect(files.every((file) => !file.existsSync()), isTrue);
      await platform.dispose();
      await platform.play(Uint8List(0));
      await queue.cancel();
      await started.close();
    },
  );

  test('native output errors reach the caller and dispose cancels an active decoder', () async {
    final output = createAudioPreviewPlatform(
      startProcess: (binary, args) async => _Process(code: 2, error: 'device unavailable'),
    );
    await expectLater(
      output.play(Uint8List.fromList([1])),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('device unavailable'),
        ),
      ),
    );
    await output.dispose();

    final data = StreamController<List<int>>();
    final started = Completer<_Process>();
    final decoder = createAudioPreviewPlatform(
      startProcess: (binary, args) async {
        final process = _Process(
          code: null,
          output: data.stream,
          onKill: () => unawaited(data.close()),
        );
        started.complete(process);
        return process;
      },
    );
    final pending = decoder.decode(const AudioSource.file('/long.wav'));
    final expectation = expectLater(pending, throwsStateError);
    final process = await started.future;
    await Future<void>.delayed(Duration.zero);
    await decoder.dispose();
    await expectation;
    expect(process.killed, isTrue);
  });

  test('native decode launch cancellation reaps its child and rejects late data', () async {
    final launched = Completer<void>();
    final pendingProcess = Completer<Process>();
    final platform = createAudioPreviewPlatform(
      startProcess: (binary, args) {
        launched.complete();
        return pendingProcess.future;
      },
    );
    final decode = platform.decode(const AudioSource.file('/late.wav'));
    final failed = expectLater(decode, throwsStateError);
    await launched.future;
    await platform.dispose();
    final process = _Process(code: null, output: Stream.value(_pcm()));
    pendingProcess.complete(process);
    await failed;
    expect(process.killed, isTrue);
  });

  test('native decode bounds PCM before allocating the double sample cache', () async {
    final process = _Process(
      code: null,
      output: Stream.value(Uint8List(64 * 1024 * 1024 + 4)),
    );
    final platform = createAudioPreviewPlatform(startProcess: (binary, args) async => process);
    addTearDown(platform.dispose);
    await expectLater(
      platform.decode(const AudioSource.file('/oversized.wav')),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('128 MiB'))),
    );
    expect(process.killed, isTrue);
  });

  test('native launch failures still remove their staged source', () async {
    late File staged;
    final platform = createAudioPreviewPlatform(
      startProcess: (binary, args) async {
        staged = File(args[args.indexOf('-i') + 1]);
        throw const ProcessException('ffmpeg', [], 'missing executable');
      },
    );
    addTearDown(platform.dispose);
    await expectLater(
      platform.decode(AudioSource.memory(Uint8List.fromList([1, 2]))),
      throwsA(isA<ProcessException>()),
    );
    expect(staged.existsSync(), isFalse);
  });
}
