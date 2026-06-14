// Fixture for the nondeterministic_random unit test.
// ignore_for_file: unused_local_variable

import 'dart:math';

void renderFrame() {
  // Unseeded Random(): the determinism trap.
  final a = Random();

  // DateTime.now(): wall-clock in render code.
  final t = DateTime.now();

  // Seeded Random(seed): deterministic, allowed.
  final b = Random(42);

  // Random.secure(): named, not the unseeded trap, allowed.
  final c = Random.secure();
}
