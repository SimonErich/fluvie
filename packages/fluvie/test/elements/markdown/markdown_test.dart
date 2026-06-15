// WI-18 (D-Markdown/D-Files): the public Markdown widget. It parses-cached,
// renders via the AstRenderer, and applies the optional block-by-block reveal
// (staggerOffsetFrames over the block count). Mount under the frame clock +
// timing scopes (mirroring counter_test / code_test).

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/transition/shared_element.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/code/code.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/markdown/markdown.dart';
import 'package:fluvie/src/elements/markdown/parse/markdown_parser.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/scene_scope.dart';
import 'package:fluvie/src/timing/video_scope.dart';

Future<void> _pumpAt(
  WidgetTester tester,
  Widget subject, {
  int frame = 0,
  int sceneFrames = 60,
}) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: VideoScope(
        fps: 30,
        duration: Time.frames(sceneFrames),
        child: SceneScope(duration: Time.frames(sceneFrames), child: subject),
      ),
    ),
  ),
);

/// The number of laid-out Text widgets currently in the tree.
int _textCount(WidgetTester tester) => tester.widgetList<Text>(find.byType(Text)).length;

/// The first [WidgetSpan] child anywhere under [root].
Widget? _findWidgetSpanChild(TextSpan root) {
  for (final child in root.children ?? const <InlineSpan>[]) {
    if (child is WidgetSpan) return child.child;
    if (child is TextSpan) {
      final found = _findWidgetSpanChild(child);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  setUp(clearMarkdownCache);

  group('Markdown rendering', () {
    testWidgets('renders a heading and a paragraph', (tester) async {
      await _pumpAt(tester, const Markdown('# Title\n\nbody text'));
      expect(find.text('Title', findRichText: true), findsOneWidget);
      expect(find.text('body text', findRichText: true), findsOneWidget);
    });

    testWidgets('a fenced block delegates to a Code widget', (tester) async {
      await _pumpAt(tester, const Markdown('```dart\nvoid main() {}\n```'));
      expect(find.byType(Code), findsOneWidget);
      expect(tester.widget<Code>(find.byType(Code)).language, 'dart');
    });

    test('an image delegates to an Image widget', () {
      // Inspect the rendered blocks directly (no mount, so the async network
      // load never fires): the image rides a WidgetSpan inside the paragraph.
      const widget = Markdown('![alt](http://x/y.png)');
      final blocks = widget.blocksFor(parseMarkdownCached('![alt](http://x/y.png)'));
      final span = ((blocks.single as Padding).child! as Text).textSpan! as TextSpan;
      expect(_findWidgetSpanChild(span), isA<Image>());
    });

    testWidgets('content-params only: no transform without .animate()', (tester) async {
      await _pumpAt(tester, const Markdown('plain'));
      // A bare Markdown mounts no SharedElement and no Transform of its own.
      expect(find.byType(SharedElement), findsNothing);
    });

    testWidgets('shared wraps the result in a SharedElement', (tester) async {
      await _pumpAt(tester, Markdown('plain', shared: Anchor('md')));
      expect(find.byType(SharedElement), findsOneWidget);
    });
  });

  group('Markdown block-by-block reveal', () {
    const doc = '# One\n\ntwo\n\nthree\n\nfour';

    testWidgets('instant (no reveal) shows every block at frame 0', (tester) async {
      await _pumpAt(tester, const Markdown(doc));
      expect(_textCount(tester), greaterThanOrEqualTo(4));
    });

    testWidgets('a reveal shows only block 0 at an early frame', (tester) async {
      await _pumpAt(
        tester,
        const Markdown(doc, reveal: Time.frames(20)),
        sceneFrames: 120,
      );
      // At frame 0, only the first block has crossed its offset.
      expect(_textCount(tester), 1);
    });

    testWidgets('a reveal shows every block at the end', (tester) async {
      await _pumpAt(
        tester,
        const Markdown(doc, reveal: Time.frames(20)),
        frame: 119,
        sceneFrames: 120,
      );
      expect(_textCount(tester), greaterThanOrEqualTo(4));
    });
  });
}
