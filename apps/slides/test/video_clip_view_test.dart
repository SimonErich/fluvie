import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slides/decks/support/video_clip_view.dart';

void main() {
  testWidgets('off the web the clip shows a labeled placeholder', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: VideoClipView(
          assetPath: 'assets/videos/lukas_birthday.mp4',
          label: 'the birthday clip',
        ),
      ),
    );
    expect(find.textContaining('the birthday clip'), findsOneWidget);
    expect(find.textContaining('plays in the web build'), findsOneWidget);
  });
}
