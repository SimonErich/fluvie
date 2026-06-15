// WI-20 (D-CaptionsRender, §17): captions mount in the Video shell as the top
// scene-spanning layer. A Video(captions: ...) under a resolver renders the
// active cue at its timestamp; two builds of the same frame are identical.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/captions/runtime/captions_layer.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _source = CaptionSource.srt('en.srt');

List<CaptionCue> _cues() => [CaptionCue('Hello world', start: 0.0.seconds, end: 4.seconds)];

Future<FakeMediaResolver> _resolver() async {
  final resolver = FakeMediaResolver(const {}, captionCues: {_source: _cues()});
  await resolver.preResolveCaptions(_source);
  return resolver;
}

Widget _app(FakeMediaResolver resolver, RenderController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: RenderControllerScope(
    controller: controller,
    child: ImageResolverScope(
      resolver: resolver,
      child: Video(
        captions: const Captions.fromSrt('en.srt'),
        width: 200,
        height: 120,
        scenes: [Scene(duration: 4.seconds)],
      ),
    ),
  ),
);

void main() {
  testWidgets('mounts a CaptionsLayer when the Video declares captions', (tester) async {
    final resolver = await _resolver();
    await tester.pumpWidget(_app(resolver, RenderController(initialFrame: 30)));
    await tester.pump();
    expect(find.byType(CaptionsLayer), findsOneWidget);
  });

  testWidgets('renders the cue text at its timestamp through the shell', (tester) async {
    final resolver = await _resolver();
    await tester.pumpWidget(_app(resolver, RenderController(initialFrame: 30)));
    await tester.pump();
    expect(find.text('Hello world'), findsOneWidget);
  });

  testWidgets('mounts no CaptionsLayer when the Video declares no captions', (tester) async {
    final resolver = await _resolver();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RenderControllerScope(
          controller: RenderController(),
          child: ImageResolverScope(
            resolver: resolver,
            child: Video(
              width: 200,
              height: 120,
              scenes: [Scene(duration: 4.seconds)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CaptionsLayer), findsNothing);
  });

  testWidgets('two builds of the same frame render identical caption text', (tester) async {
    final resolver = await _resolver();
    await tester.pumpWidget(_app(resolver, RenderController(initialFrame: 60)));
    await tester.pump();
    final first = find.text('Hello world').evaluate().length;
    await tester.pump();
    final second = find.text('Hello world').evaluate().length;
    expect(first, second);
    expect(first, 1);
  });
}
