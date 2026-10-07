import 'package:flutter/widgets.dart' hide Clip;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Clip, MediaSource;
import 'package:fluvie/src/media/runtime/resolved_image.dart';
import 'tiny_png.dart';

void main() {
  testWidgets('a preview without frames shows the poster instead of the label', (tester) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 160,
          height: 90,
          child: Clip.asset('fixtures/clip.mp4', poster: MediaSource.memory(tinyPng)),
        ),
      ),
    );
    final image = tester.widget<ResolvedImage>(find.byType(ResolvedImage));
    expect(image.source, MediaSource.memory(tinyPng));
    expect(find.textContaining('clip.mp4'), findsNothing);
  });

  testWidgets('without a poster the labelled placeholder stands in', (tester) async {
    await tester.pumpWidget(
      Center(
        child: SizedBox(width: 160, height: 90, child: Clip.asset('fixtures/clip.mp4')),
      ),
    );
    expect(find.byType(ResolvedImage), findsNothing);
    expect(find.textContaining('clip.mp4'), findsOneWidget);
  });

  test('the poster rides every factory', () {
    const poster = MediaSource.asset('poster.png');
    expect(Clip.asset('a.mp4', poster: poster).poster, poster);
    expect(Clip.network(Uri.parse('https://cdn.example.com/a.mp4'), poster: poster).poster, poster);
    expect(Clip.file('/tmp/a.mp4', poster: poster).poster, poster);
  });
}
