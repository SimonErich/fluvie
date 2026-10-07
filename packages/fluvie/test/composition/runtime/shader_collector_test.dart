// collectShaderAssets is the sibling of collectMediaSources: a structural walk
// that finds every fragment-shader asset a composition will paint, so the warm
// pass can load each one before frame 0. Pure, no mounting.

import 'package:flutter/widgets.dart' show Color, ColoredBox, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/composition/runtime/shader_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/time.dart';

const _box = ColoredBox(color: Color(0xFF223344));

void main() {
  test('finds the asset of every shader animation in the tree', () {
    final scenes = [
      Scene(
        duration: const Time.frames(30),
        children: [
          _box.animate([Animation.shader('shaders/ripple.frag')]),
        ],
      ),
    ];

    expect(collectShaderAssets(scenes), {'shaders/ripple.frag'});
  });

  test('two elements on one asset collect it once', () {
    final scenes = [
      Scene(
        duration: const Time.frames(30),
        children: [
          _box.animate([Animation.shader('shaders/ripple.frag')]),
          _box.animate([Animation.shader('shaders/ripple.frag')]),
        ],
      ),
    ];

    expect(collectShaderAssets(scenes), hasLength(1));
  });

  test('walks into nested children and a scene background', () {
    final scenes = [
      Scene(
        duration: const Time.frames(30),
        children: [
          SizedBox(
            child: _box.animate([Animation.shader('shaders/nested.frag')]),
          ),
        ],
      ),
    ];

    expect(collectShaderAssets(scenes), {'shaders/nested.frag'});
  });

  test('a composition with no shader collects nothing', () {
    final scenes = [
      Scene(
        duration: const Time.frames(30),
        children: [
          _box.animate([Animation.fadeIn()]),
        ],
      ),
    ];

    expect(collectShaderAssets(scenes), isEmpty);
  });

  test('a non-shader pixel effect is not mistaken for one', () {
    final scenes = [
      Scene(
        duration: const Time.frames(30),
        children: [
          _box.animate([Animation.grain(0.2)]),
        ],
      ),
    ];

    expect(collectShaderAssets(scenes), isEmpty);
  });
}
