// The Playground golden: the reusable widget in its idle, no-video state — the
// seeded editor, a clean diagnostics summary, the Render button, and the
// empty-state video area. The backend is faked so the post-frame validation
// stays offline, and the stub (non-web) video area avoids the HTML element.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/playground.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';

import 'fake_playground_backend.dart';

Future<void> main() async {
  await goldenTest(
    'playground idle state',
    fileName: 'playground_idle',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'seeded editor, no video',
          child: SizedBox(
            width: 520,
            height: 760,
            child: ProviderScope(
              overrides: [
                playgroundBackendProvider.overrideWithValue(FakePlaygroundBackend()),
              ],
              child: const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(body: Playground()),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
