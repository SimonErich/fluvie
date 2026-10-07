import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/captions/runtime/caption_cue_view.dart';

void main() {
  testWidgets('review reports measured overflow, reading window and unbundled font', (
    tester,
  ) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundary,
            child: const SizedBox(
              width: 50,
              height: 30,
              child: Text(
                'Several words that cannot fit on one short line',
                maxLines: 1,
                style: TextStyle(fontFamily: 'UnbundledFixture', fontSize: 20),
              ),
            ),
          ),
        ),
      ),
    );
    final findings = inspectRenderedText(
      boundaryKey: boundary,
      frame: 3,
      fps: 30,
      totalFrames: 15,
      bundledFonts: const {},
    );
    expect(
      findings.map((finding) => finding['code']),
      containsAll([
        'text_overflow',
        'text_too_brief',
        'font_not_bundled',
      ]),
    );
    expect(findings.every((finding) => finding['frame'] == 3), isTrue);
  });

  testWidgets('short text with room and a bundled font produces no finding', (tester) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundary,
            child: const Text('Hello', style: TextStyle(fontFamily: 'Fixture')),
          ),
        ),
      ),
    );
    expect(
      inspectRenderedText(
        boundaryKey: boundary,
        frame: 0,
        fps: 30,
        totalFrames: 120,
        bundledFonts: const {'Fixture'},
      ),
      isEmpty,
    );
  });
  testWidgets('caption reading checks use the actual cue window rather than video duration', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: CaptionCueView(
            cue: CaptionCue(
              'Several words need time to read',
              start: const Time.frames(30),
              end: const Time.frames(36),
            ),
            frame: 32,
            scope: const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300),
            style: const CaptionStyle.subtitle(),
            position: const CaptionPosition.bottomThird(),
          ),
        ),
      ),
    );
    final finding = inspectRenderedText(
      boundaryKey: key,
      frame: 32,
      fps: 30,
      totalFrames: 300,
      bundledFonts: const {},
    ).firstWhere((finding) => finding['code'] == 'text_too_brief');
    expect(finding['startFrame'], 30);
    expect(finding['endFrame'], 36);
  });
}
