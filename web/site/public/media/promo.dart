import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Video build() => Video(
  size: const VideoSize(320, 320),
  fps: 12,
  poster: 3.seconds,
  scenes: [
    Scene.centered(
      duration: 10.seconds,
      background: Background.color(const Color(0xFF0E9E8E)),
      child: Counter(
        to: 10000,
        reveal: 3.seconds,
        style: const TextStyle(fontSize: 48, color: Colors.white),
      ),
    ),
  ],
);
