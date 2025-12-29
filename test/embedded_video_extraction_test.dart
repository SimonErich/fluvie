import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  group('EmbeddedVideo extraction', () {
    test('extracts EmbeddedVideo from nested VPositioned -> AnimatedProp -> Container', () {
      // Create a Video with EmbeddedVideo nested in custom widgets
      final video = Video(
        fps: 30,
        width: 1080,
        height: 1920,
        scenes: [
          Scene(
            durationInFrames: 240,
            children: [
              VPositioned(
                top: 750,
                left: 90,
                child: AnimatedProp(
                  animation: const TranslateAnimation(
                    start: Offset(0, 30),
                    end: Offset.zero,
                  ),
                  duration: 35,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: EmbeddedVideo(
                      assetPath: 'assets/test_video.mp4',
                      width: 900,
                      height: 500,
                      startFrame: 40,
                      durationInFrames: 200,
                      includeAudio: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      // Extract embedded video configs
      final configs = video.extractEmbeddedVideoConfigs();

      // Should find the EmbeddedVideo
      expect(configs.length, equals(1));
      expect(configs[0].videoPath, equals('assets/test_video.mp4'));
      expect(configs[0].durationInFrames, equals(200));
      expect(configs[0].includeAudio, isTrue);
    });

    test('extracts EmbeddedVideo directly in scene children', () {
      final video = Video(
        fps: 30,
        width: 1080,
        height: 1920,
        scenes: [
          Scene(
            durationInFrames: 100,
            children: [
              EmbeddedVideo(
                assetPath: 'assets/direct_video.mp4',
                width: 640,
                height: 360,
                startFrame: 0,
                durationInFrames: 100,
              ),
            ],
          ),
        ],
      );

      final configs = video.extractEmbeddedVideoConfigs();
      expect(configs.length, equals(1));
      expect(configs[0].videoPath, equals('assets/direct_video.mp4'));
    });

    test('extracts EmbeddedVideo from Year Review Scene 6 structure', () {
      // Replicate the exact structure of Scene 6 from example_year_review.dart
      final video = Video(
        fps: 30,
        width: 1080,
        height: 1920,
        scenes: [
          Scene(
            durationInFrames: 240,
            children: [
              // Film grain effect
              EffectOverlay.grain(intensity: 0.06),
              // Vignette
              EffectOverlay.vignette(intensity: 0.4),
              // Play button indicator - VPositioned without EmbeddedVideo
              VPositioned(
                top: 300,
                left: 0,
                right: 0,
                startFrame: 5,
                fadeInFrames: 20,
                child: const Center(
                  child: SizedBox(width: 120, height: 120),
                ),
              ),
              // Title - VPositioned with Column
              VPositioned(
                top: 500,
                left: 0,
                right: 0,
                child: Column(
                  children: const [
                    Text('YOUR TOP'),
                    SizedBox(height: 8),
                    Text('VIDEO MOMENT'),
                  ],
                ),
              ),
              // Video preview - the key one with EmbeddedVideo
              VPositioned(
                top: 750,
                left: 90,
                startFrame: 40,
                fadeInFrames: 25,
                child: AnimatedProp(
                  animation: const TranslateAnimation(
                    start: Offset(0, 30),
                    end: Offset.zero,
                  ),
                  startFrame: 40,
                  duration: 35,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: EmbeddedVideo(
                      assetPath: 'assets/demo_data/highlight.mp4',
                      width: 900,
                      height: 500,
                      startFrame: 40,
                      durationInFrames: 200,
                      borderRadius: BorderRadius.circular(20),
                      includeAudio: true,
                      audioVolume: 1.0,
                    ),
                  ),
                ),
              ),
              // View count
              VPositioned(
                bottom: 220,
                left: 0,
                right: 0,
                startFrame: 130,
                fadeInFrames: 20,
                child: const Text('58'),
              ),
            ],
          ),
        ],
      );

      // Extract embedded video configs
      final configs = video.extractEmbeddedVideoConfigs();

      // Should find the EmbeddedVideo
      expect(configs.length, equals(1), reason: 'Should find exactly 1 EmbeddedVideo');
      expect(configs[0].videoPath, equals('assets/demo_data/highlight.mp4'));
      expect(configs[0].durationInFrames, equals(200));
      expect(configs[0].includeAudio, isTrue);
      expect(configs[0].startFrame, equals(40)); // sceneStartFrame (0) + widget.startFrame (40)
    });
  });
}
