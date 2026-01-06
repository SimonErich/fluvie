@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import '../../helpers/golden_helpers.dart';

void main() {
  group('Effects Widget Goldens', () {
    group('EffectOverlay', () {
      testWidgets('scanlines effect', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.blue,
                child: const Center(
                  child: Text(
                    'Scanlines',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const EffectOverlay.scanlines(intensity: 0.1),
            ],
          ),
          name: 'widgets/effects/scanlines',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('grain effect', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.green,
                child: const Center(
                  child: Text(
                    'Grain',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const EffectOverlay.grain(intensity: 0.15, randomSeed: 123),
            ],
          ),
          name: 'widgets/effects/grain',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('vignette effect', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.orange,
                child: const Center(
                  child: Text(
                    'Vignette',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const EffectOverlay.vignette(intensity: 0.5),
            ],
          ),
          name: 'widgets/effects/vignette',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('combined effects', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.purple,
                child: const Center(
                  child: Text(
                    'Combined',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const EffectOverlay.scanlines(intensity: 0.05),
              const EffectOverlay.grain(intensity: 0.1, randomSeed: 456),
              const EffectOverlay.vignette(intensity: 0.4),
            ],
          ),
          name: 'widgets/effects/combined',
          frame: 0,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('grid effect', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.black,
                child: const Center(
                  child: Text(
                    'Grid',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const EffectOverlay.grid(
                intensity: 0.15,
                color: Colors.cyan,
              ),
            ],
          ),
          name: 'widgets/effects/grid',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('crt effect', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.teal,
                child: const Center(
                  child: Text(
                    'CRT',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const EffectOverlay.crt(intensity: 0.3),
            ],
          ),
          name: 'widgets/effects/crt',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('ParticleEffect', () {
      testWidgets('sparkles preset', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.black,
                child: const Center(
                  child: Text(
                    'Sparkles',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const ParticleEffect.sparkles(count: 30),
            ],
          ),
          name: 'widgets/effects/sparkles',
          frame: 15,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('confetti preset', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.white,
                child: const Center(
                  child: Text(
                    'Confetti',
                    style: TextStyle(color: Colors.black, fontSize: 32),
                  ),
                ),
              ),
              const ParticleEffect.confetti(count: 50),
            ],
          ),
          name: 'widgets/effects/confetti',
          frame: 15,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('snow preset', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.blueGrey.shade800,
                child: const Center(
                  child: Text(
                    'Snow',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const ParticleEffect.snow(count: 40),
            ],
          ),
          name: 'widgets/effects/snow',
          frame: 15,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });

      testWidgets('bubbles preset', (tester) async {
        await expectGolden(
          tester,
          Stack(
            children: [
              Container(
                color: Colors.blue.shade900,
                child: const Center(
                  child: Text(
                    'Bubbles',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
              const ParticleEffect.bubbles(count: 25),
            ],
          ),
          name: 'widgets/effects/bubbles',
          frame: 15,
          size: GoldenConfig.smallSize,
          durationInFrames: 60,
        );
      });
    });

    group('MaskedClip', () {
      testWidgets('circle mask', (tester) async {
        await expectGolden(
          tester,
          VCenter(
            child: MaskedClip.circle(
              radius: 100,
              child: Container(
                width: 200,
                height: 200,
                color: Colors.red,
                child: const Center(
                  child: Text(
                    'Circle',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          name: 'widgets/effects/mask_circle',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('rectangle mask with border radius', (tester) async {
        await expectGolden(
          tester,
          VCenter(
            child: MaskedClip.rectangle(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 250,
                height: 150,
                color: Colors.blue,
                child: const Center(
                  child: Text(
                    'Rounded',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          name: 'widgets/effects/mask_rounded',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('star mask', (tester) async {
        await expectGolden(
          tester,
          VCenter(
            child: MaskedClip.star(
              radius: 100,
              starPoints: 5,
              child: Container(
                width: 200,
                height: 200,
                color: Colors.amber,
                child: const Center(
                  child: Text(
                    'Star',
                    style: TextStyle(color: Colors.black, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          name: 'widgets/effects/mask_star',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('heart mask', (tester) async {
        await expectGolden(
          tester,
          VCenter(
            child: MaskedClip.heart(
              radius: 80,
              child: Container(
                width: 200,
                height: 200,
                color: Colors.pink,
                child: const Center(
                  child: Text(
                    'Heart',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
          name: 'widgets/effects/mask_heart',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('circle mask with reveal animation', (tester) async {
        await expectGolden(
          tester,
          VCenter(
            child: MaskedClip.circle(
              radius: 150,
              animation: const MaskAnimation.reveal(duration: 60),
              child: Container(
                width: 300,
                height: 300,
                color: Colors.deepPurple,
                child: const Center(
                  child: Text(
                    'Reveal',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
            ),
          ),
          name: 'widgets/effects/mask_reveal_30',
          frame: 30,
          size: GoldenConfig.smallSize,
          durationInFrames: 90,
        );
      });
    });
  });
}
