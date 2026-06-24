import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:web_browser_studio/maker/maker_state.dart';
import 'package:web_browser_studio/maker/maker_view_model.dart';
import 'package:web_browser_studio/render/web_render_service.dart';

class _FakeRenderService implements WebRenderService {
  Uint8List? downloaded;
  String? filename;
  bool fail = false;

  @override
  Future<Uint8List> render(
    Widget composition, {
    required Aspect aspect,
    required Duration duration,
    RenderProgressCallback? onProgress,
  }) async {
    if (fail) throw StateError('wasm boom');
    onProgress?.call(
      const RenderProgress(
        RenderPhase.capturing,
        completedFrames: 6,
        totalFrames: 12,
      ),
    );
    return Uint8List.fromList(List<int>.filled(128, 7));
  }

  @override
  void download(Uint8List bytes, String name) {
    downloaded = bytes;
    filename = name;
  }
}

ProviderContainer _container(WebRenderService service) {
  final container = ProviderContainer(
    overrides: [webRenderServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts in editing with default meme text', () {
    final container = _container(_FakeRenderService());

    final state = container.read(makerViewModelProvider);

    expect(state.status, MakerStatus.editing);
    expect(state.topText, isNotEmpty);
    expect(state.bottomText, isNotEmpty);
  });

  test('makeMp4 renders, downloads, and ends in done', () async {
    final service = _FakeRenderService();
    final container = _container(service);

    await container.read(makerViewModelProvider.notifier).makeMp4();
    final state = container.read(makerViewModelProvider);

    expect(state.status, MakerStatus.done);
    expect(state.progress, 1);
    expect(service.downloaded, isNotNull);
    expect(service.filename, 'kitten_meme.mp4');
  });

  test('makeMp4 surfaces a failure as the failed status', () async {
    final container = _container(_FakeRenderService()..fail = true);

    await container.read(makerViewModelProvider.notifier).makeMp4();
    final state = container.read(makerViewModelProvider);

    expect(state.status, MakerStatus.failed);
    expect(state.error, contains('boom'));
  });
}
