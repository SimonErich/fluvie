import 'package:desktop_studio/render/render_service.dart';
import 'package:desktop_studio/render/save_dialog_service.dart';
import 'package:desktop_studio/studio/studio_state.dart';
import 'package:desktop_studio/studio/studio_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSave implements SaveDialogService {
  _FakeSave(this.path);

  final String? path;

  @override
  Future<String?> chooseSavePath(String suggestedName) async => path;
}

class _FakeRender implements RenderService {
  _FakeRender({this.error}) : result = null;

  final RenderResult? result;
  final Exception? error;
  String? lastKey;
  bool? lastDraft;

  @override
  Future<RenderResult> render({
    required String key,
    required String outputPath,
    bool draft = false,
  }) async {
    lastKey = key;
    lastDraft = draft;
    if (error != null) throw error!;
    return result ?? RenderResult(outputPath: outputPath, bytes: 4096);
  }
}

ProviderContainer _container({
  required SaveDialogService save,
  required RenderService render,
}) {
  final container = ProviderContainer(
    overrides: [
      saveDialogServiceProvider.overrideWithValue(save),
      renderServiceProvider.overrideWithValue(render),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('render writes the chosen file and ends in done', () async {
    final render = _FakeRender();
    final container = _container(
      save: _FakeSave('/tmp/out.mp4'),
      render: render,
    );

    await container.read(studioViewModelProvider.notifier).render();
    final state = container.read(studioViewModelProvider);

    expect(state.status, StudioStatus.done);
    expect(state.result!.outputPath, '/tmp/out.mp4');
    expect(render.lastKey, 'studio_promo');
  });

  test('cancelling the save dialog leaves the studio idle', () async {
    final render = _FakeRender();
    final container = _container(save: _FakeSave(null), render: render);

    await container.read(studioViewModelProvider.notifier).render();
    final state = container.read(studioViewModelProvider);

    expect(state.status, StudioStatus.idle);
    expect(render.lastKey, isNull);
  });

  test('a render failure surfaces the error', () async {
    final container = _container(
      save: _FakeSave('/tmp/out.mp4'),
      render: _FakeRender(error: const RenderException('boom')),
    );

    await container.read(studioViewModelProvider.notifier).render();
    final state = container.read(studioViewModelProvider);

    expect(state.status, StudioStatus.failed);
    expect(state.error, contains('boom'));
  });

  test(
    'selecting a template passes the draft flag through to the render',
    () async {
      final render = _FakeRender();
      final container = _container(
        save: _FakeSave('/tmp/out.mp4'),
        render: render,
      );
      final vm = container.read(studioViewModelProvider.notifier)
        ..selectTemplate('studio_meme')
        ..toggleDraft();

      await vm.render();

      expect(render.lastKey, 'studio_meme');
      expect(render.lastDraft, isTrue);
    },
  );
}
