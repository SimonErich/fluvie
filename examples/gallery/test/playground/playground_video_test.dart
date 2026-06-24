import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/playground_video.dart';

void main() {
  testWidgets('shows the empty-state prompt when there is no url', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlaygroundVideo(url: null))),
    );

    expect(find.textContaining('Render to see your video'), findsOneWidget);
  });

  testWidgets('shows a ready affordance when a url is set', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PlaygroundVideo(url: 'https://api.test/v.mp4')),
      ),
    );

    expect(find.textContaining('Render to see your video'), findsNothing);
    expect(find.byType(PlaygroundVideo), findsOneWidget);
  });
}
