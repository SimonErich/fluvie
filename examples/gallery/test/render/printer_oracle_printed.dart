// GENERATED-EQUIVALENT FIXTURE — the body below (from the `import` line down) is
// byte-identical to `printVideoSpecJson(printerOracleSpec)`, asserted by
// printer_oracle_render_test.dart. It is checked in so `flutter test` can JIT
// compile and render path B (the printed code cannot be compiled from a dynamic
// string in a single test run). Regenerate by re-printing the spec; keep the two
// in lock-step. The printer emits Playground-grade Dart that does not add `const`
// or trim default arguments, so silence those info lints here (they are blocking
// under --fatal-infos) without altering the asserted body text.
//
// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_redundant_argument_values
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Video build() {
  final title = Anchor('title');
  return Video(
    size: VideoSize.square,
    scenes: [
      Scene(
        duration: 1.seconds,
        background: Background.gradient(
          [Color(0xFF101820), Color(0xFF203040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        children: [
          Text(
            'Hello',
            style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 64, fontWeight: FontWeight.bold),
          ).animate([Animation.fadeIn(duration: 0.4.seconds)], anchor: title),
          Box(
            color: Color(0xFF00A0FF),
            size: Size(200, 120),
          ).animate([Animation.slideFade(from: Edge.left, at: Trigger.after(title))]),
        ],
      ),
      Scene(
        duration: 1.seconds,
        background: Background.color(Color(0xFF000000)),
        children: [
          Counter(
            to: 100,
            from: 0,
            duration: 0.8.seconds,
            style: TextStyle(color: Color(0xFFFFFF00), fontSize: 48),
          ),
          Text('Raw', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 40)).animate([
            Animation.fromTo(
              Keyframe(scale: 0, origin: Alignment.topLeft),
              Keyframe(scale: 1, rotation: 0.25, origin: Alignment.center),
              duration: 0.5.seconds,
              ease: Ease.inOut,
              at: Trigger.at(0.2.seconds),
            ),
          ]),
        ],
      ),
    ],
  );
}
