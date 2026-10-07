import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

import 'fakes/fake_wasm_runtime.dart';

class _LifecycleRuntime extends FakeWasmRuntime implements WasmRuntimeLifecycle {
  int loads = 0;
  int terminations = 0;
  final started = Completer<void>();
  Completer<void>? loading;
  Completer<int>? executing;
  final deleted = <String>[];

  @override
  Future<void> load() async {
    loads++;
    if (loading != null) {
      if (!started.isCompleted) started.complete();
      await loading!.future;
    }
  }

  @override
  Future<int> exec(List<String> args) async {
    if (!started.isCompleted) started.complete();
    if (executing != null) return executing!.future;
    return super.exec(args);
  }

  @override
  Future<void> terminate() async {
    terminations++;
    files.clear();
    if (loading case final pending? when !pending.isCompleted) {
      pending.completeError(StateError('Terminated during load'));
    }
    if (executing case final pending? when !pending.isCompleted) {
      pending.completeError(StateError('Terminated during execution'));
    }
    loading = null;
    executing = null;
  }

  @override
  Future<void> deleteFile(String name) async {
    deleted.add(name);
    files.remove(name);
  }
}

RenderManifest get _manifest => RenderManifest(
  width: 4,
  height: 4,
  fps: 30,
  frameCount: 1,
  framesFileName: 'frames.rgba',
  outputFileName: 'out.mp4',
  renderDigest: 'digest',
  ffmpegArgs: const ['-i', 'frames.rgba', 'out.mp4'],
);

Future<MemoryRenderSandbox> _sandbox() async {
  final sandbox = MemoryRenderSandbox();
  await sandbox.writeBytes('frames.rgba', Uint8List.fromList([1, 2, 3]));
  return sandbox;
}

void main() {
  test('cancellable encode refuses a runtime without lifecycle support before staging', () async {
    final runtime = FakeWasmRuntime();
    final sandbox = await _sandbox();
    final encoder = WebVideoEncoder(runtime: runtime);
    await expectLater(
      encoder.encode(
        manifest: _manifest,
        sandbox: sandbox,
        cancellation: RenderCancellation(),
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('lifecycle bridge'),
        ),
      ),
    );
    expect(runtime.files, isEmpty);
    expect(runtime.lastArgs, isNull);
    expect(await sandbox.readBytes('frames.rgba'), [1, 2, 3]);
    // The refusal does not poison a legacy runtime's ordinary encode path.
    expect(await encoder.encode(manifest: _manifest, sandbox: sandbox), isNotEmpty);
  });

  test('an already cancelled request exits before checking backend capability', () async {
    final runtime = FakeWasmRuntime();
    final token = RenderCancellation()..cancel();
    await expectLater(
      WebVideoEncoder(runtime: runtime).encode(
        manifest: _manifest,
        sandbox: await _sandbox(),
        cancellation: token,
      ),
      throwsA(isA<RenderCancelledException>()),
    );
    expect(runtime.files, isEmpty);
    expect(runtime.lastArgs, isNull);
  });

  for (final loading in [false, true]) {
    test(
      'cancel during ${loading ? 'load' : 'exec'} terminates, reloads and cleans next job',
      () async {
        final runtime = _LifecycleRuntime();
        if (loading) {
          runtime.loading = Completer<void>();
        } else {
          runtime.executing = Completer<int>();
        }
        final encoder = WebVideoEncoder(runtime: runtime);
        final token = RenderCancellation();
        final pending = encoder.encode(
          manifest: _manifest,
          sandbox: await _sandbox(),
          cancellation: token,
        );
        final result = expectLater(pending, throwsA(isA<RenderCancelledException>()));
        await runtime.started.future;
        token.cancel();
        await result;
        expect(runtime.terminations, 1);
        expect(runtime.files, isEmpty);

        final out = await encoder.encode(manifest: _manifest, sandbox: await _sandbox());
        expect(out, isNotEmpty);
        expect(runtime.loads, 2);
        expect(runtime.files, isEmpty);
        expect(runtime.deleted, containsAll(['frames.rgba', 'out.mp4']));
      },
    );
  }

  test('cancel after completion cannot terminate a later job', () async {
    final runtime = _LifecycleRuntime();
    final token = RenderCancellation();
    await WebVideoEncoder(runtime: runtime).encode(
      manifest: _manifest,
      sandbox: await _sandbox(),
      cancellation: token,
    );
    token.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.terminations, 0);
  });
}
