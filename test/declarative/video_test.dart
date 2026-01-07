import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/core/video.dart';
import 'package:fluvie/src/declarative/core/scene.dart';
import 'package:fluvie/src/declarative/core/scene_transition.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/presentation/video_composition.dart';

void main() {
  group('Video', () {
    group('construction', () {
      test('creates with required scenes parameter', () {
        const video = Video(
          scenes: [],
        );

        expect(video.scenes, isEmpty);
      });

      test('has default fps of 30', () {
        const video = Video(scenes: []);
        expect(video.fps, 30);
      });

      test('has default width of 1080', () {
        const video = Video(scenes: []);
        expect(video.width, 1080);
      });

      test('has default height of 1920', () {
        const video = Video(scenes: []);
        expect(video.height, 1920);
      });

      test('supports custom fps', () {
        const video = Video(fps: 60, scenes: []);
        expect(video.fps, 60);
      });

      test('supports custom dimensions', () {
        const video = Video(
          width: 1920,
          height: 1080,
          scenes: [],
        );
        expect(video.width, 1920);
        expect(video.height, 1080);
      });

      test('supports default transition', () {
        const video = Video(
          defaultTransition: SceneTransition.crossFade(),
          scenes: [],
        );
        expect(video.defaultTransition, isNotNull);
      });

      test('supports background music configuration', () {
        const video = Video(
          backgroundMusicAsset: 'assets/music.mp3',
          musicVolume: 0.8,
          musicFadeInFrames: 60,
          musicFadeOutFrames: 45,
          scenes: [],
        );
        expect(video.backgroundMusicAsset, 'assets/music.mp3');
        expect(video.musicVolume, 0.8);
        expect(video.musicFadeInFrames, 60);
        expect(video.musicFadeOutFrames, 45);
      });

      test('has default music volume of 1.0', () {
        const video = Video(scenes: []);
        expect(video.musicVolume, 1.0);
      });

      test('has default music fade frames of 30', () {
        const video = Video(scenes: []);
        expect(video.musicFadeInFrames, 30);
        expect(video.musicFadeOutFrames, 30);
      });
    });

    group('totalDuration', () {
      test('returns 0 for empty scenes', () {
        const video = Video(scenes: []);
        expect(video.totalDuration, 0);
      });

      test('returns single scene duration', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 120, children: []),
          ],
        );
        expect(video.totalDuration, 120);
      });

      test('sums multiple scene durations', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 100, children: []),
            Scene(durationInFrames: 50, children: []),
            Scene(durationInFrames: 75, children: []),
          ],
        );
        expect(video.totalDuration, 225); // 100 + 50 + 75
      });
    });

    group('startFrameForScene', () {
      test('returns 0 for first scene', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 100, children: []),
            Scene(durationInFrames: 50, children: []),
          ],
        );
        expect(video.startFrameForScene(0), 0);
      });

      test('returns correct start for second scene', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 100, children: []),
            Scene(durationInFrames: 50, children: []),
          ],
        );
        expect(video.startFrameForScene(1), 100);
      });

      test('returns correct start for third scene', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 100, children: []),
            Scene(durationInFrames: 50, children: []),
            Scene(durationInFrames: 75, children: []),
          ],
        );
        expect(video.startFrameForScene(2), 150); // 100 + 50
      });

      test('handles index beyond scenes length', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 100, children: []),
          ],
        );
        expect(video.startFrameForScene(5), 100); // Returns total duration
      });
    });

    group('toConfig', () {
      test('creates RenderConfig with correct timeline', () {
        const video = Video(
          fps: 60,
          width: 1920,
          height: 1080,
          scenes: [
            Scene(durationInFrames: 120, children: []),
            Scene(durationInFrames: 60, children: []),
          ],
        );

        final config = video.toConfig();

        expect(config, isA<RenderConfig>());
        expect(config.timeline.fps, 60);
        expect(config.timeline.width, 1920);
        expect(config.timeline.height, 1080);
        expect(config.timeline.durationInFrames, 180); // 120 + 60
      });

      test('includes encoding config if provided', () {
        const video = Video(
          encoding: EncodingConfig(frameFormat: FrameFormat.png),
          scenes: [
            Scene(durationInFrames: 100, children: []),
          ],
        );

        final config = video.toConfig();

        expect(config.encoding, isNotNull);
        expect(config.encoding!.frameFormat, FrameFormat.png);
      });
    });

    group('widget build', () {
      testWidgets('renders VideoComposition', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Video(
              scenes: [
                Scene(durationInFrames: 100, children: []),
              ],
            ),
          ),
        );

        expect(find.byType(VideoComposition), findsOneWidget);
      });

      testWidgets('VideoComposition has correct properties', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Video(
              fps: 60,
              width: 1920,
              height: 1080,
              scenes: [
                Scene(durationInFrames: 150, children: []),
              ],
            ),
          ),
        );

        final composition = tester.widget<VideoComposition>(
          find.byType(VideoComposition),
        );

        expect(composition.fps, 60);
        expect(composition.width, 1920);
        expect(composition.height, 1080);
        expect(composition.durationInFrames, 150);
      });

      testWidgets('renders scene children', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Video(
              scenes: [
                Scene(
                  durationInFrames: 100,
                  children: [
                    Container(
                        key: const Key('scene-content'), color: Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        );

        expect(find.byKey(const Key('scene-content')), findsOneWidget);
      });

      testWidgets('renders multiple scenes', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Video(
              scenes: [
                Scene(durationInFrames: 100, children: [Text('Scene 1')]),
                Scene(durationInFrames: 100, children: [Text('Scene 2')]),
              ],
            ),
          ),
        );

        // Video with multiple scenes should render without error
        // At frame 0, only the first scene content is visible
        expect(find.byType(Video), findsOneWidget);
        expect(find.text('Scene 1'), findsOneWidget);
      });
    });

    group('scene context', () {
      testWidgets('renders scenes with context available', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Video(
              scenes: [
                Scene(
                  durationInFrames: 100,
                  children: [
                    Builder(
                      builder: (context) {
                        // SceneContext.of accesses InheritedWidget
                        SceneContext.of(context);
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        // Verify the widget renders without error
        expect(find.byType(Video), findsOneWidget);
      });
    });

    group('encoding config', () {
      test('supports EncodingConfig', () {
        const video = Video(
          encoding: EncodingConfig(frameFormat: FrameFormat.png),
          scenes: [],
        );

        expect(video.encoding, isNotNull);
        expect(video.encoding!.frameFormat, FrameFormat.png);
      });

      testWidgets('passes encoding to VideoComposition', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Video(
              encoding: EncodingConfig(frameFormat: FrameFormat.png),
              scenes: [
                Scene(durationInFrames: 100, children: []),
              ],
            ),
          ),
        );

        final composition = tester.widget<VideoComposition>(
          find.byType(VideoComposition),
        );

        expect(composition.encoding, isNotNull);
        expect(composition.encoding!.frameFormat, FrameFormat.png);
      });
    });

    group('edge cases', () {
      test('handles empty scenes list', () {
        const video = Video(scenes: []);
        expect(video.totalDuration, 0);
        expect(video.startFrameForScene(0), 0);
      });

      test('handles single frame scene', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 1, children: []),
          ],
        );
        expect(video.totalDuration, 1);
      });

      test('handles very long video', () {
        const video = Video(
          scenes: [
            Scene(durationInFrames: 100000, children: []),
          ],
        );
        expect(video.totalDuration, 100000);
      });
    });
  });
}
