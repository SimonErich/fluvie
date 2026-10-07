// Compiled minimal native mobile render example; contains no reactive analysis.
// #docregion mobile-render
import 'dart:io';

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

Future<File> renderSimpleVideo() => OnDeviceVideoRenderer().render(
  composition: Video(
    scenes: [
      Scene.centered(
        duration: 2.seconds,
        background: Background.color(Colors.teal),
        child: const Text('Hello, Fluvie', style: TextStyle(fontSize: 64, color: Colors.white)),
      ),
    ],
  ),
  aspect: Aspect.square,
  duration: const Duration(seconds: 2),
  longEdge: 480,
);
// #enddocregion mobile-render
