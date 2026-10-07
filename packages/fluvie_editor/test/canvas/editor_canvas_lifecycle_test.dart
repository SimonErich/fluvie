import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaSource;
import 'package:fluvie/rendering.dart' show MediaResolver;
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:mocktail/mocktail.dart';
import 'package:obers_ui/obers_ui.dart';

final class _ControlledResolver extends Mock implements MediaResolver {
  final release = Completer<void>();
  int requests = 0;

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) {
    expect(sources, isEmpty);
    requests++;
    return release.future;
  }
}

EditorDocument _document() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '120f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#D74F39'},
      'children': [
        {
          'id': 'box',
          'type': 'Box',
          'color': '#5A73D8',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.25, 'h': 0.25},
        },
        {
          'id': 'title',
          'type': 'Text',
          'text': 'Canvas',
          'style': {'fontSize': 18, 'color': '#FFFFFF'},
          'transform': {'x': 0.5, 'y': 0.2, 'w': 0.6, 'h': 0.2},
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
  ],
});

final class _CanvasFixture {
  _CanvasFixture({this.whole = false, this.dark = true})
    : transport = SlideTransport(fps: 30, length: 120, initialFrame: whole ? 5 : 30);

  final bool whole;
  final bool dark;
  final EditorDocument document = _document();
  final container = ProviderContainer();
  final viewport = CanvasViewportController();
  final SlideTransport transport;
  final resolver = _ControlledResolver();
  final ready = <MediaResolver>[];
  final commands = <EditorCommand>[];
  final TargetPlatform? oldPlatform = debugDefaultTargetPlatformOverride;

  EditorCanvas canvas({MediaResolver? resolver, void Function(EditorCommand)? onCommand}) =>
      EditorCanvas(
        key: const ValueKey('retained-canvas'),
        document: document,
        slide: 0,
        viewportController: viewport,
        interactive: whole,
        wholeDocument: whole,
        transport: transport,
        settleFrame: 30,
        mediaResolver: resolver ?? this.resolver,
        onCommand: onCommand ?? commands.add,
        onMediaReady: ready.add,
      );

  Future<void> replace(WidgetTester tester, EditorCanvas child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OiApp(
          title: 'Canvas regression',
          theme: dark ? OiThemeData.dark() : OiThemeData.light(),
          debugShowCheckedModeBanner: false,
          home: Center(child: SizedBox(width: 800, height: 600, child: child)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  }

  Future<void> mount(WidgetTester tester, {bool failMedia = false}) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    await tester.binding.setSurfaceSize(const Size(800, 600));
    await replace(tester, canvas());
    await tester.pump();
    expect(resolver.requests, 1);
    if (failMedia) {
      resolver.release.completeError(StateError('controlled media failure'));
    } else {
      resolver.release.complete();
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  }

  Offset center(WidgetTester tester) =>
      tester.getTopLeft(find.byType(EditorCanvas)) + viewport.toViewport(const Offset(160, 90));

  Future<void> close(WidgetTester tester) async {
    try {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      if (!resolver.release.isCompleted) resolver.release.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    } finally {
      container.dispose();
      transport.dispose();
      viewport.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
      debugDefaultTargetPlatformOverride = oldPlatform;
    }
  }
}

void main() {
  for (final dark in [true, false]) {
    testWidgets('media failure uses semantic text color in the ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      final fixture = _CanvasFixture(dark: dark);
      try {
        await fixture.mount(tester, failMedia: true);
        final error = find.textContaining('Media preview unavailable:');
        expect(error, findsOneWidget);
        final context = tester.element(error);
        final painted = tester.renderObject<RenderParagraph>(error).text.style?.color;
        expect(painted, context.colors.text);
        final textLuminance = painted!.computeLuminance();
        final surfaceLuminance = context.colors.surface.computeLuminance();
        final brighter = textLuminance > surfaceLuminance ? textLuminance : surfaceLuminance;
        final darker = textLuminance < surfaceLuminance ? textLuminance : surfaceLuminance;
        expect((brighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    });
  }

  testWidgets('noninteractive media recovery keeps one resolver request and ready callback', (
    tester,
  ) async {
    final fixture = _CanvasFixture();
    final replacement = _ControlledResolver();
    try {
      await fixture.mount(tester, failMedia: true);
      expect(
        find.textContaining('Media preview unavailable: Bad state: controlled media failure'),
        findsOneWidget,
      );
      expect(fixture.ready, isEmpty);
      await fixture.replace(tester, fixture.canvas(resolver: replacement));
      await tester.pump();
      expect(replacement.requests, 1);
      replacement.release.complete();
      await tester.pump();
      await tester.pump();
      expect(replacement.requests, 1);
      expect(fixture.ready, [same(replacement)]);
      expect(find.textContaining('Media preview unavailable:'), findsNothing);
      expect(find.text('Canvas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      if (!replacement.release.isCompleted) replacement.release.complete();
      await fixture.close(tester);
    }
  });

  testWidgets('first settled-frame crossing updates the gate and current command handler', (
    tester,
  ) async {
    final fixture = _CanvasFixture(whole: true);
    final current = <EditorCommand>[];
    try {
      await fixture.mount(tester);
      expect(find.text('Scrub to the settled frame to edit'), findsOneWidget);
      await tester.tapAt(fixture.center(tester), kind: PointerDeviceKind.mouse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(fixture.commands, isEmpty);
      fixture.transport.seek(30);
      await tester.pump();
      expect(find.text('Scrub to the settled frame to edit'), findsNothing);
      await fixture.replace(tester, fixture.canvas(onCommand: current.add));
      await tester.tapAt(fixture.center(tester), kind: PointerDeviceKind.mouse);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(fixture.commands, isEmpty);
      expect(current, hasLength(1));
      expect(current.single, isA<SetTransformsCommand>());
      expect(current.single.affectedIds, {'box'});
      final moved = current.single.apply(fixture.document);
      final transform = moved.elementJson('box')!['transform']! as Map;
      expect(transform['x'], closeTo(0.5 + 1 / 320, 1e-12));
      expect(transform['y'], 0.5);
      expect(fixture.document.elementJson('box')!['transform'], containsPair('x', 0.5));
      expect(tester.takeException(), isNull);
    } finally {
      await fixture.close(tester);
    }
  });
}
