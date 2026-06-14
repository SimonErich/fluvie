// Fixture: an unseeded Random() in render code trips nondeterministic_random.
// A seeded Random(seed) is the deterministic path and stays silent.
// ignore_for_file: unused_local_variable

import 'dart:math';

void renderFrame() {
  // expect_lint: nondeterministic_random
  final jitter = Random();

  // Seeded: deterministic, not flagged.
  final seeded = Random(7);
}
