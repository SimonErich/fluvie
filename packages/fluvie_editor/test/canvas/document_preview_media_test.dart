import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaSource;
import 'package:fluvie/rendering.dart' show ClipMetadata, MediaResolver;
import 'package:fluvie_editor/fluvie_editor.dart';

final class _Resolver implements MediaResolver {
  _Resolver(this.image, this.gate);
  final ui.Image image;
  final Future<void> gate;
  final frames = <int>{};
  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) => gate;
  @override
  Future<ClipMetadata> probeClip(MediaSource source) async => clipMetadataFor(source);
  @override
  ClipMetadata clipMetadataFor(MediaSource source) =>
      (fps: 30, frameCount: 60, width: 32, height: 18, hasAudio: false);
  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async {
    frames.addAll(sourceFrames);
  }

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) {
    if (!frames.contains(sourceFrame)) throw StateError('Frame was not decoded');
    return image;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ui.Image> _green() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 32, 18), ui.Paint()..color = const ui.Color(0xff00ff00));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(32, 18);
  } finally {
    picture.dispose();
  }
}

Widget _host(GlobalKey<DocumentPreviewHostState> key, MediaResolver resolver) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: DocumentPreviewHost(
      key: key,
      thumbWidth: 32,
      mediaResolver: resolver,
      document: EditorDocument.fromJson(const {
        'fluvieSpec': 1,
        'fps': 30,
        'size': {'width': 32, 'height': 18},
        'scenes': [
          {
            'duration': '1s',
            'children': [
              {
                'type': 'Clip',
                'source': {'kind': 'file', 'value': '/clip.mp4'},
                'trim': {'from': '1s', 'to': '2s'},
              },
            ],
          },
        ],
      }),
    ),
  ),
);

void main() {
  testWidgets('still capture waits for decoded trimmed clip pixels', (tester) async {
    final image = await _green();
    addTearDown(image.dispose);
    final gate = Completer<void>();
    final resolver = _Resolver(image, gate.future);
    final key = GlobalKey<DocumentPreviewHostState>();
    await tester.pumpWidget(_host(key, resolver));
    var completed = false;
    final pending = key.currentState!.render(0);
    unawaited(pending.then((_) => completed = true));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(completed, isFalse, reason: 'A pending clip must not export its placeholder');
    gate.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    final captured = (await tester.runAsync(() => pending))!;
    addTearDown(captured.dispose);
    final pixels = (await tester.runAsync<ByteData?>(captured.toByteData))!;
    expect(pixels.buffer.asUint8List().sublist((9 * 32 + 16) * 4, (9 * 32 + 16) * 4 + 4), [
      0,
      255,
      0,
      255,
    ]);
    expect(resolver.frames, {30}, reason: 'A still needs only its exact settled source frame');
    await tester.pump();
  });

  testWidgets('failed media aborts the still export with its source error', (tester) async {
    final image = await _green();
    addTearDown(image.dispose);
    final gate = Completer<void>();
    final key = GlobalKey<DocumentPreviewHostState>();
    await tester.pumpWidget(_host(key, _Resolver(image, gate.future)));
    final pending = key.currentState!
        .render(0)
        .then<Object>((value) => value, onError: (Object error) => error);
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    gate.completeError(StateError('Source unavailable'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(
      await pending,
      isA<StateError>().having((error) => error.message, 'message', 'Source unavailable'),
    );
    expect(tester.takeException(), isNull);
  });
}
