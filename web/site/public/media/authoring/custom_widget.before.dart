// #docregion video
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// Small authored fixture for measuring edits that preserve custom Flutter code.
Video build() => Video(
  size: const VideoSize(160, 160),
  scenes: [
    Scene(duration: 3.seconds, background: Background.color(Colors.indigo),
      children: [const Text('Milo plays', style: TextStyle(fontSize: 20)), const BenchmarkBadge()]),
  ],
);
// #enddocregion video

// #docregion custom-widget
/// Handwritten Flutter widget retained byte-for-byte by the benchmark edit.
final class BenchmarkBadge extends StatelessWidget {
  /// Creates the fixture badge.
  const BenchmarkBadge({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(8),
    child: Text('Handwritten Flutter', style: TextStyle(fontSize: 12, color: Colors.amber)),
  );
}
// #enddocregion custom-widget
