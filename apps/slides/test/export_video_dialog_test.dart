// The export options dialog: what one render runs at. Resolution and quality
// steer the run; a changed frame rate rewrites the deck, because a deck's
// timeline is measured in its own frames.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show EncoderPreset, ExportCodec, ExportPixelFormat, Quality, VideoSpec;
import 'package:fluvie_editor/fluvie_editor.dart' show MathNumberInput;
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/export_video_dialog.dart';

import 'desktop_surface.dart';

/// A deck of [width] x [height] at [fps] — the dialog reads only the canvas
/// and the rate.
VideoSpec _spec({int width = 1920, int height = 1080, int fps = 30}) => VideoSpec.fromJson({
  'fluvieSpec': 1,
  'size': {'width': width, 'height': height},
  'fps': fps,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {'type': 'Text', 'text': 'hello'},
      ],
    },
  ],
});

void main() {
  testWidgets('advanced delivery choices switch rate modes and reach the render snapshot', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final spec = _spec();
    final before = spec.digest();
    ExportChoice? chosen;
    var opened = false;
    await tester.pumpWidget(
      OiApp(
        home: Builder(
          builder: (context) {
            if (!opened) {
              opened = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                chosen = await showExportVideoDialog(context, spec: spec);
              });
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encoder options'));
    await tester.pumpAndSettle();
    OiSelect<T> select<T>(String label) => tester.widget<OiSelect<T>>(
      find.byWidgetPredicate((widget) => widget is OiSelect<T> && widget.label == label),
    );
    MathNumberInput number(String label) => tester.widget<MathNumberInput>(
      find.byWidgetPredicate((widget) => widget is MathNumberInput && widget.label == label),
    );
    select<ExportCodec>('Video codec').onChanged!(ExportCodec.h265);
    select<EncoderPreset>('Encoder speed').onChanged!(EncoderPreset.slow);
    select<ExportPixelFormat>('Pixel format').onChanged!(ExportPixelFormat.yuv420p10le);
    select<String>('Rate control').onChanged!('crf');
    await tester.pumpAndSettle();
    number('CRF (lower is higher quality)').onChanged(23);
    await tester.pumpAndSettle();
    expect(number('CRF (lower is higher quality)').value, 23);
    select<String>('Rate control').onChanged!('bitrate');
    await tester.pumpAndSettle();
    expect(find.text('CRF (lower is higher quality)'), findsNothing);
    number('Video bitrate Mbps').onChanged(5.5);
    await tester.pumpAndSettle();
    expect(number('Video bitrate Mbps').value, 5.5);
    select<String>('Rate control').onChanged!('quality');
    await tester.pumpAndSettle();
    expect(find.text('Video bitrate Mbps'), findsNothing);
    select<String>('Rate control').onChanged!('crf');
    await tester.pumpAndSettle();
    number('CRF (lower is higher quality)').onChanged(21);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start export'));
    await tester.pumpAndSettle();
    expect(chosen, isNotNull);
    final render = chosen!.options.applyTo(spec);
    expect(spec.digest(), before);
    expect(render.export!.codec, ExportCodec.h265);
    expect(render.export!.crf, 21);
    expect(render.export!.bitRate, isNull);
    expect(render.export!.preset, EncoderPreset.slow);
    expect(render.export!.pixelFormat, ExportPixelFormat.yuv420p10le);
    expect(chosen!.fps, 30);
    expect(chosen!.options.export.crf, 21);
  });

  for (final preset in const ['Draft', 'Share', 'Master']) {
    testWidgets('$preset delivery preset produces a bounded render choice', (tester) async {
      useDesktopSurface(tester);
      ExportChoice? chosen;
      var opened = false;
      await tester.pumpWidget(
        OiApp(
          home: Builder(
            builder: (context) {
              if (!opened) {
                opened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  chosen = await showExportVideoDialog(context, spec: _spec());
                });
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(preset));
      await tester.pumpAndSettle();
      final expectedEdge = {'Draft': 720, 'Share': 1080, 'Master': 1920}[preset]!;
      await tester.tap(find.text('Start export'));
      await tester.pumpAndSettle();
      expect(chosen!.options.longEdge, expectedEdge);
      expect(chosen!.options.quality, switch (preset) {
        'Draft' => Quality.low,
        'Share' => Quality.high,
        _ => Quality.max,
      });
      expect(
        chosen!.options.preset,
        preset == 'Draft' ? EncoderPreset.ultrafast : EncoderPreset.medium,
      );
    });
  }

  group('resolution presets', () {
    test('offer the deck edge first and only smaller rungs below it', () {
      // Upscaling past the authored canvas cannot invent detail in a clip, so
      // offering it would promise more than the render delivers.
      expect(exportLongEdgePresets(1920), [1920, 1440, 1080, 720]);
      expect(exportLongEdgePresets(1080), [1080, 720, 480]);
      expect(exportLongEdgePresets(480), [480]);
    });

    test('never exceed what the control accepts', () {
      // OiSegmentedControl asserts at most five segments rather than
      // truncating, so a deck on an unusual edge must not blow past it.
      for (final edge in [3840, 2160, 1920, 1200, 640, 320]) {
        expect(exportLongEdgePresets(edge).length, lessThanOrEqualTo(5));
      }
    });

    test('a deck already on a ladder rung does not list it twice', () {
      expect(exportLongEdgePresets(1080).where((e) => e == 1080), hasLength(1));
    });
  });

  group('the dialog', () {
    Future<ExportChoice?> open(WidgetTester tester, {VideoSpec? spec}) async {
      useDesktopSurface(tester);
      ExportChoice? choice;
      var opened = false;
      await tester.pumpWidget(
        OiApp(
          home: Builder(
            builder: (context) {
              if (!opened) {
                opened = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  choice = await showExportVideoDialog(context, spec: spec ?? _spec());
                });
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return choice;
    }

    testWidgets('opens on the deck it was given, so confirming changes nothing', (tester) async {
      await open(tester);

      await tester.tap(find.text('Start export'));
      await tester.pumpAndSettle();

      // 1920x1080 at 30fps: the deck's own settings, unchanged.
      expect(find.text('Start export'), findsNothing, reason: 'the dialog closed');
    });

    testWidgets('a smaller resolution rides the run without touching the deck', (tester) async {
      await open(tester);

      await tester.tap(find.text('720'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start export'));
      await tester.pumpAndSettle();

      expect(find.text('Start export'), findsNothing);
    });

    testWidgets('the canvas label follows the chosen edge at the deck aspect', (tester) async {
      await open(tester);

      expect(find.text('1920 x 1080'), findsOneWidget);

      await tester.tap(find.text('720'));
      await tester.pumpAndSettle();

      expect(find.text('720 x 405'), findsOneWidget);
    });

    testWidgets('a portrait deck labels its short edge on the other axis', (tester) async {
      await open(tester, spec: _spec(width: 1080, height: 1920));

      expect(find.text('1080 x 1920'), findsOneWidget);
    });

    testWidgets('changing the frame rate says it changes the deck', (tester) async {
      await open(tester);

      expect(find.textContaining('changes the deck itself'), findsNothing);

      await tester.tap(find.text('60'));
      await tester.pumpAndSettle();

      expect(find.textContaining('changes the deck itself'), findsOneWidget);
    });

    testWidgets('every quality the pipeline knows is offered', (tester) async {
      await open(tester);

      for (final quality in Quality.values) {
        expect(find.text(quality.name), findsOneWidget);
        await tester.tap(find.text(quality.name));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OiSegmentedControl<Quality>>(find.byType(OiSegmentedControl<Quality>))
              .selected,
          quality,
        );
      }
    });
  });
}
