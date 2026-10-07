import 'dart:async';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

void main() {
  testWidgets('a stage torn down mid-render leaves its host safe to finish', (tester) async {
    await tester.pumpWidget(const FluvieWebStage(child: SizedBox.shrink()));
    final host = FluvieWebStage.hostFor(const Size(8, 8));

    final mounting = host.mount(const SizedBox.shrink());
    await tester.pump();
    await mounting;

    // The app navigates away (or hot-restarts) while the render still holds
    // the stage it bound at mount time.
    await tester.pumpWidget(const SizedBox.shrink());

    // The render's own teardown must not reach into the slot the disposed
    // stage left behind.
    await host.dispose();

    // A frame the render still asks for has to settle too, rather than park
    // on one the disposed stage will never schedule.
    var pumped = false;
    unawaited(host.pumpFrame().then((_) => pumped = true));
    await tester.idle();
    expect(pumped, isTrue, reason: 'a gone stage answers with no frame instead of none at all');
  });

  testWidgets('a capture without a stage says what to mount', (tester) async {
    final host = FluvieWebStage.hostFor(const Size(8, 8));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      () => host.mount(const SizedBox.shrink()),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('No FluvieWebStage is mounted'),
        ),
      ),
    );
  });
}
