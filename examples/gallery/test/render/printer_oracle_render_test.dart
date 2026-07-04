// The RENDER counterpart to fluvie_server's compile-only printer oracle
// (packages/fluvie_server/test/api/render/printed_code_compiles_test.dart,
// tag `analysis`). That test proves the printed Dart ANALYZES; this one proves
// the printed Dart RENDERS the same frames as the spec it came from — the
// semantic-fidelity oracle the plan called for.
//
// Strategy B (a checked-in fixture). The printed code is a dynamic string, and a
// single `flutter test` run can only JIT-compile statically imported sources, so
// path B cannot compile the string in process. Instead:
//   * printerOracleSpec (below) is the spec S.
//   * printer_oracle_printed.dart holds D: a `Video build()` whose body is
//     byte-identical to printVideoSpecJson(S), checked in so it compiles and
//     renders here. printer_oracle_expected.dart.txt is the same text as a
//     golden, so drift in either direction is caught.
// The test asserts printVideoSpecJson(S) == golden == D's body (text fidelity),
// then captures frames for buildVideo(S) and for D's build() through the SAME
// production capture shell and asserts the RGBA frames match (render fidelity).
// Transitively: printer(S) renders like S.
//
// Tags: `render` (it drives the capture pipeline) — no ffmpeg, the frames are
// read straight off the RepaintBoundary, so no `ffmpeg` tag is needed.
@Tags(['render'])
@Timeout(Duration(minutes: 5))
library;

// printVideoSpecJson is @experimental in fluvie_cli; this oracle pins it.
// ignore_for_file: experimental_member_use
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart' show loadFonts;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';
import 'package:fluvie_cli/fluvie_cli.dart' show printVideoSpecJson;
import 'package:fluvie_example/render/spec_composition.dart';

import 'printer_oracle_printed.dart' as printed;

/// The fixture spec S: two scenes; a gradient and a color background; a styled
/// Text, a Box, a Counter; a preset with a non-default arg (`fadeIn(duration:)`),
/// a raw `fromTo` keyframe pair, and an anchor + `Trigger.whenEnds` so the
/// anchor-variable reconstruction is exercised end to end. Kept short (2s total)
/// so it captures quickly.
final Map<String, Object?> printerOracleSpec = {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '1s',
      'background': {
        'kind': 'gradient',
        'colors': ['#FF101820', '#FF203040'],
        'begin': 'topLeft',
        'end': 'bottomRight',
      },
      'children': [
        {
          'type': 'Text',
          'text': 'Hello',
          'anchor': 'title',
          'style': {'color': '#FFFFFFFF', 'fontSize': 64, 'fontWeight': 'bold'},
          'animate': [
            {'preset': 'fadeIn', 'duration': '0.4s'},
          ],
        },
        {
          'type': 'Box',
          'color': '#FF00A0FF',
          'size': {'width': 200, 'height': 120},
          'animate': [
            {
              'preset': 'slideFade',
              'from': 'left',
              'at': {'kind': 'whenEnds', 'anchor': 'title'},
            },
          ],
        },
      ],
    },
    {
      'duration': '1s',
      'background': {'kind': 'color', 'color': '#FF000000'},
      'children': [
        {
          'type': 'Counter',
          'to': 100,
          'from': 0,
          'duration': '0.8s',
          'style': {'color': '#FFFFFF00', 'fontSize': 48},
        },
        {
          'type': 'Text',
          'text': 'Raw',
          'style': {'color': '#FFFFFFFF', 'fontSize': 40},
          'animate': [
            {
              'from': {'scale': 0, 'origin': 'topLeft'},
              'to': {'scale': 1, 'rotation': 0.25, 'origin': 'center'},
              'duration': '0.5s',
              'ease': 'inOut',
              'at': {'kind': 'at', 'time': '0.2s'},
            },
          ],
        },
      ],
    },
  ],
};

/// The header the checked-in fixture carries before the printed body; the body
/// asserted against the golden starts at the first printed line.
const String _bodyStartsAt =
    "import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;";

/// The printed `build()` body of printer_oracle_printed.dart, with its leading
/// ignore/comment header stripped — i.e. exactly what the printer should emit.
String _fixtureBody() {
  final source = File(
    'test/render/printer_oracle_printed.dart',
  ).readAsStringSync();
  final start = source.indexOf(_bodyStartsAt);
  expect(start, isNonNegative, reason: 'the printed body marker must be present in the fixture');
  return source.substring(start);
}

/// Captures the [sampledFrames] frames of [build] through the production capture
/// shell at [size]x[size] (device pixel ratio 1.0), returning one [RawFrame] per
/// sampled index. This is the SAME shell + readback the headless renderer uses,
/// so a match here is a match on the real path — minus the ffmpeg encode, which
/// Fluvie does not guarantee to be byte-identical anyway.
Future<List<RawFrame>> _captureFrames({
  required WidgetTester tester,
  required Widget Function() build,
  required int size,
  required List<int> sampledFrames,
}) async {
  tester.view.physicalSize = ui.Size(size.toDouble(), size.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final controller = RenderController();
  final boundaryKey = GlobalKey();
  // Match the harness: unstyled text falls back to a real bundled family so the
  // capture shows real glyphs (both paths share it, so it cancels out, but this
  // keeps the comparison on the same pixels the renderer produces).
  final composition = DefaultTextStyle.merge(
    style: const TextStyle(fontFamily: 'Roboto'),
    child: build(),
  );
  final shell = buildCaptureShell(
    composition: composition,
    boundaryKey: boundaryKey,
    controller: controller,
  );
  await tester.pumpWidget(shell.tree);

  const capture = RepaintBoundaryCaptureService();
  final frames = <RawFrame>[];
  await tester.runAsync(() async {
    for (final frame in sampledFrames) {
      controller.seek(frame);
      await tester.pump();
      frames.add(
        await capture.capture(
          boundaryKey: boundaryKey,
          frameIndex: frame,
          width: size,
          height: size,
        ),
      );
    }
  });
  return frames;
}

void main() {
  testWidgets(
    'the printed code renders the same frames as the spec it came from',
    (tester) async {
      await loadFonts();

      final spec = VideoSpec.fromJson(printerOracleSpec);

      // 1) Text fidelity: the printer output, the checked-in golden, and the
      //    statically-imported fixture body must all be the same bytes. This pins
      //    the fixture to the printer (so the render below is over the real printed
      //    code) and catches printer drift the way the compile oracle does.
      final printedNow = printVideoSpecJson(printerOracleSpec);
      final golden = File('test/render/printer_oracle_expected.dart.txt').readAsStringSync();
      expect(
        printedNow,
        golden,
        reason:
            'printVideoSpecJson drifted from the checked-in golden. Re-print the '
            'spec and update printer_oracle_expected.dart.txt and '
            'printer_oracle_printed.dart together.',
      );
      expect(
        _fixtureBody(),
        golden,
        reason:
            'printer_oracle_printed.dart (the rendered path-B code) drifted from '
            'the golden printer output; keep them byte-identical.',
      );

      // 2) Render fidelity: capture the same frames for the spec (path A,
      //    buildVideo) and for the printed code (path B, the fixture build) and
      //    assert the RGBA bytes match frame for frame.
      final video = spec.build();
      final size = spec.size.width; // square
      expect(spec.size.width, spec.size.height, reason: 'the fixture uses a square canvas');
      // Sample across both scenes and several animation phases (enter, after-anchor
      // slide, counter tween, the raw fromTo, and the tail) without rendering all
      // 60 frames — fast but representative.
      final total = video.totalFrames;
      final sampled = <int>[
        0,
        total ~/ 8,
        total ~/ 4,
        total ~/ 2,
        (total * 5) ~/ 8,
        (total * 3) ~/ 4,
        total - 1,
      ];

      final specFrames = await _captureFrames(
        tester: tester,
        build: compositionFromSpec(spec).build,
        size: size,
        sampledFrames: sampled,
      );
      final printedFrames = await _captureFrames(
        tester: tester,
        // The checked-in fixture's top-level `Video build()` is byte-identical to
        // the printer output (asserted above); wrap it in the LTR Directionality
        // the capture canvas needs, exactly like compositionFromVideo does.
        build: () => Directionality(textDirection: TextDirection.ltr, child: printed.build()),
        size: size,
        sampledFrames: sampled,
      );

      expect(printedFrames.length, specFrames.length);
      var mismatches = 0;
      for (var i = 0; i < specFrames.length; i++) {
        if (printedFrames[i] != specFrames[i]) {
          mismatches++;
          stderr.writeln(
            'frame ${sampled[i]} differs: spec vs printed RGBA not equal '
            '(${specFrames[i].byteLength} bytes each)',
          );
        }
      }
      expect(
        mismatches,
        0,
        reason:
            '$mismatches of ${sampled.length} sampled frames differ between '
            'rendering the spec and rendering its printed Dart. The printer is not '
            'semantically faithful for printerOracleSpec.',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
