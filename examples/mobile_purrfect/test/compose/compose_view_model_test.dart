import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_purrfect/compose/compose_state.dart';
import 'package:mobile_purrfect/compose/compose_view_model.dart';
import 'package:mobile_purrfect/render/mobile_render_service.dart';
import 'package:mobile_purrfect/services/photo_picker_service.dart';
import 'package:mobile_purrfect/services/share_service.dart';

class _FakePicker implements PhotoPickerService {
  _FakePicker(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> pickImage() async => bytes;
}

class _FakeRender implements MobileRenderService {
  _FakeRender({this.error});

  final Exception? error;
  String? lastName;
  Uint8List? lastBytes;

  @override
  Future<File> render({
    required String catName,
    required String song,
    Uint8List? photoBytes,
    void Function(double progress)? onProgress,
  }) async {
    lastName = catName;
    lastBytes = photoBytes;
    onProgress?.call(0.5);
    if (error != null) throw error!;
    return File('/tmp/card.mp4');
  }
}

class _FakeShare implements ShareService {
  String? shared;

  @override
  Future<void> shareVideo(String path) async => shared = path;
}

ProviderContainer _container({
  PhotoPickerService? picker,
  MobileRenderService? render,
  ShareService? share,
}) {
  final container = ProviderContainer(
    overrides: [
      photoPickerServiceProvider.overrideWithValue(picker ?? _FakePicker(null)),
      mobileRenderServiceProvider.overrideWithValue(render ?? _FakeRender()),
      shareServiceProvider.overrideWithValue(share ?? _FakeShare()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('cannot render until a cat name is entered', () async {
    final render = _FakeRender();
    final container = _container(render: render);

    await container.read(composeViewModelProvider.notifier).render();

    expect(
      container.read(composeViewModelProvider).status,
      ComposeStatus.editing,
    );
    expect(render.lastName, isNull);
  });

  test('picking a photo stores the bytes', () async {
    final container = _container(
      picker: _FakePicker(Uint8List.fromList([1, 2, 3])),
    );

    await container.read(composeViewModelProvider.notifier).pickPhoto();

    expect(container.read(composeViewModelProvider).hasPhoto, isTrue);
  });

  test('render produces a card and ends in done', () async {
    final render = _FakeRender();
    final container = _container(render: render);
    container.read(composeViewModelProvider.notifier).setCatName('Mittens');

    await container.read(composeViewModelProvider.notifier).render();
    final state = container.read(composeViewModelProvider);

    expect(state.status, ComposeStatus.done);
    expect(state.outputPath, '/tmp/card.mp4');
    expect(render.lastName, 'Mittens');
  });

  test('a render failure surfaces the error', () async {
    final container = _container(render: _FakeRender(error: Exception('boom')));
    container.read(composeViewModelProvider.notifier).setCatName('Mittens');

    await container.read(composeViewModelProvider.notifier).render();

    expect(
      container.read(composeViewModelProvider).status,
      ComposeStatus.failed,
    );
  });

  test('share forwards the rendered path to the share service', () async {
    final share = _FakeShare();
    final container = _container(render: _FakeRender(), share: share);
    final vm = container.read(composeViewModelProvider.notifier)..setCatName('Mittens');
    await vm.render();

    await vm.share();

    expect(share.shared, '/tmp/card.mp4');
  });
}
