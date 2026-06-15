// WI-19 (D-CaptionsRender, §17): the captions layer overlay. The active cue at
// the current frame renders styled and positioned; nothing shows outside a cue;
// word-pop reuses the shared stagger/Animation pipeline (no bespoke animation
// widget); karaoke highlights the active word.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/captions/caption_position.dart';
import 'package:fluvie/src/captions/caption_style.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/captions/runtime/captions_layer.dart';
import 'package:fluvie/src/core/captions/caption_cue.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 300);

CaptionSource _source() => const CaptionSource.srt('en.srt');

List<CaptionCue> _cues() => [
  CaptionCue('Hello world', start: 0.0.seconds, end: 2.seconds),
  CaptionCue(
    'sing along now',
    start: 2.seconds,
    end: 4.seconds,
    words: [
      CaptionCueWord('sing', at: 2.seconds),
      CaptionCueWord('along', at: 3.seconds),
      CaptionCueWord('now', at: 3.5.seconds),
    ],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Captions captions,
  required int frame,
}) async {
  final resolver = FakeMediaResolver(const {}, captionCues: {_source(): _cues()});
  await resolver.preResolveCaptions(_source());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ImageResolverScope(
        resolver: resolver,
        child: TimeScopeProvider(
          scope: _scope,
          child: FrameProvider(
            frame: frame,
            child: CaptionsLayer(captions: captions),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('CaptionsLayer active cue', () {
    testWidgets('shows the active cue text at its frame', (tester) async {
      await _pump(tester, captions: const Captions.fromSrt('en.srt'), frame: 15);
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('shows nothing outside every cue window', (tester) async {
      // Both fixture cues end by frame 120; frame 1000 is past them all.
      await _pump(tester, captions: const Captions.fromSrt('en.srt'), frame: 1000);
      expect(find.text('Hello world'), findsNothing);
      expect(find.text('sing along now'), findsNothing);
    });

    testWidgets('switches to the second cue in its window', (tester) async {
      await _pump(tester, captions: const Captions.fromSrt('en.srt'), frame: 75);
      expect(find.text('Hello world'), findsNothing);
      expect(find.textContaining('sing'), findsWidgets);
    });
  });

  group('CaptionsLayer positioning', () {
    testWidgets('aligns the block per the caption position', (tester) async {
      await _pump(
        tester,
        captions: const Captions.fromSrt('en.srt', position: CaptionPosition.topThird()),
        frame: 15,
      );
      final align = tester.widget<Align>(
        find.ancestor(of: find.text('Hello world'), matching: find.byType(Align)).first,
      );
      expect(align.alignment, const CaptionPosition.topThird().alignment);
    });
  });

  group('CaptionsLayer word-pop', () {
    testWidgets('wraps popping words in Transform (no bespoke animation widget)', (tester) async {
      await _pump(
        tester,
        captions: const Captions.fromSrt('en.srt', style: CaptionStyle.tikTok()),
        frame: 2, // mid-pop of the first cue's first word
      );
      // The pop is a Transform.scale, the shared widget — not a new animation type.
      expect(find.byType(Transform), findsWidgets);
    });
  });

  group('CaptionsLayer karaoke', () {
    testWidgets('renders the karaoke cue word by word', (tester) async {
      await _pump(
        tester,
        captions: const Captions.fromSrt('en.srt', style: CaptionStyle.karaoke()),
        frame: 90, // 3.0s: the second word is active
      );
      expect(find.text('sing'), findsOneWidget);
      expect(find.text('along'), findsOneWidget);
      expect(find.text('now'), findsOneWidget);
    });
  });

  group('CaptionsLayer without a resolver (preview)', () {
    testWidgets('shows nothing when no resolver is in scope', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: TimeScopeProvider(
            scope: _scope,
            child: FrameProvider(
              frame: 15,
              child: CaptionsLayer(captions: Captions.fromSrt('en.srt')),
            ),
          ),
        ),
      );
      expect(find.text('Hello world'), findsNothing);
    });
  });
}
