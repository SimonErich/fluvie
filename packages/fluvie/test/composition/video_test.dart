import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/audio.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/composition/runtime/transition_compositor.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// A probe leaf reporting the nearest scope to [onScope].
Widget _probe(void Function(TimeScopeData scope) onScope) => Builder(
  builder: (context) {
    onScope(TimeScopeProvider.of(context));
    return const SizedBox.shrink();
  },
);

/// Mounts [video] under a frame clock positioned at [frame].
Widget _harness(Video video, {int frame = 0}) => RenderControllerScope(
  controller: RenderController(initialFrame: frame),
  child: video,
);

void main() {
  group('Video — duration math (D27)', () {
    test('totalFrames sums the scenes across mixed units', () {
      final video = Video(
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 30.frames),
          Scene(duration: 500.ms),
        ],
      );
      expect(video.totalFrames, 60 + 30 + 15);
    });

    test('sceneStartFrames are the running offsets', () {
      final video = Video(
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 30.frames),
          Scene(duration: 500.ms),
        ],
      );
      expect(video.sceneStartFrames, [0, 60, 90]);
    });

    test('an empty scenes list throws an ArgumentError at construction', () {
      expect(() => Video(scenes: const <Scene>[]), throwsArgumentError);
    });

    test('a relative scene duration throws via the shared resolver (WI-5)', () {
      final video = Video(
        scenes: [
          Scene(duration: 2.seconds),
          Scene(duration: 0.5.relative),
        ],
      );
      expect(
        () => video.totalFrames,
        throwsA(
          isA<FluvieTimingError>().having(
            (e) => e.message,
            'message',
            contains("'scenes[1]'"),
          ),
        ),
      );
      expect(() => video.sceneStartFrames, throwsA(isA<FluvieTimingError>()));
    });
  });

  group('Video — size and inert data (D7)', () {
    test('a size preset wins over width and height', () {
      final video = Video(size: VideoSize.hd, width: 10, height: 20, scenes: [_scene()]);
      expect(video.width, 1920);
      expect(video.height, 1080);
    });

    test('without a preset the loose dimensions apply, defaulting to reels', () {
      expect(Video(scenes: [_scene()]).width, 1080);
      expect(Video(scenes: [_scene()]).height, 1920);
      expect(Video(width: 320, height: 240, scenes: [_scene()]).width, 320);
      expect(Video(width: 320, height: 240, scenes: [_scene()]).height, 240);
    });

    test('audio, captions, export, poster, and defaults are carried verbatim', () {
      const audio = [Audio.music('song.mp3')];
      const captions = Captions.fromSrt('en.srt');
      const export = Export.gif(fps: 12);
      const defaults = Defaults(duration: Time.seconds(1));
      final video = Video(
        scenes: [_scene()],
        audio: audio,
        captions: captions,
        export: export,
        motionDefaults: defaults,
        poster: 1.seconds,
      );
      expect(video.audio, same(audio));
      expect(video.captions, same(captions));
      expect(video.export, same(export));
      expect(video.motionDefaults, same(defaults));
      expect(video.poster, 1.seconds);
    });
  });

  group('Video — the scene shell (D6)', () {
    testWidgets('mounts every scene in one TransitionCompositor over a shared Stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Video(
            scenes: [
              _scene(),
              Scene(duration: 1.seconds),
            ],
          ),
        ),
      );
      final compositor = tester.widget<TransitionCompositor>(
        find.byType(TransitionCompositor),
      );
      // No transition: the offsets are the plain running sums and all-cut.
      expect(compositor.offsets.startFrames, [0, 60]);
      expect(compositor.offsets.totalFrames, 90);
      expect(compositor.sceneShells, hasLength(2));
      // No opinion anywhere: one boundary, resolved to null (a cut).
      expect(compositor.transitions, [null]);
      final stack = tester.widget<Stack>(
        find.descendant(of: find.byType(TransitionCompositor), matching: find.byType(Stack)).first,
      );
      expect(stack.fit, StackFit.expand);
      expect(find.byType(Scene, skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('the root scope carries the fps and the summed duration', (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        _harness(
          Video(
            scenes: [
              Scene(duration: 2.seconds, children: [_probe((scope) => seen = scope)]),
              Scene(duration: 30.frames),
            ],
          ),
        ),
      );
      expect(seen.parent, const TimeScopeData(fps: 30, startFrame: 0, durationFrames: 90));
    });

    testWidgets("scene 2's scope starts exactly where scene 1 ends", (tester) async {
      late TimeScopeData seen;
      await tester.pumpWidget(
        _harness(
          Video(
            scenes: [
              Scene(duration: 2.seconds),
              Scene(duration: 30.frames, children: [_probe((scope) => seen = scope)]),
            ],
          ),
        ),
      );
      expect(seen.startFrame, 60);
      expect(seen.durationFrames, 30);
    });

    testWidgets('the State is the public VideoState (tester surface)', (tester) async {
      await tester.pumpWidget(_harness(Video(scenes: [_scene()])));
      expect(tester.state(find.byType(Video)), isA<VideoState>());
    });
  });
}

Scene _scene() => Scene(duration: 2.seconds);
