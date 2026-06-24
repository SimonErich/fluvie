// The one inspector shell golden (WI-22): the whole screen in its initial
// state — lesson 01 selected, the preview at frame 0, the structured
// inspector panel (warnings band, anchors, motion rows) in the right pane.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/inspector/inspector_screen.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';

import '../playground/fake_playground_backend.dart';

Future<void> main() async {
  await goldenTest(
    'inspector shell in its initial state (WI-36)',
    fileName: 'inspector_shell',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'lesson 01 at frame 0',
          child: SizedBox(
            width: 1280,
            height: 800,
            child: ProviderScope(
              // A fake backend keeps the Playground's init validation
              // deterministic (no markers) so the shell golden is stable.
              overrides: [
                playgroundBackendProvider.overrideWithValue(FakePlaygroundBackend()),
              ],
              child: const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: InspectorScreen(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
