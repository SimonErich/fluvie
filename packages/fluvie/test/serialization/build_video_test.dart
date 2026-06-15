import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/timeline_probe.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/video_spec.dart';
import 'package:fluvie/src/timing/timeline/debug_timeline.dart';

/// A two-scene document exercising backgrounds, presets, an anchor-driven
/// `Trigger.after`, a stagger, an ambient preset, a transition, and export.
Map<String, Object?> _richSpecJson() => {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'poster': '1s',
  'export': {'mode': 'mp4', 'quality': 'high'},
  'motionDefaults': {'duration': '0.4s', 'ease': 'smooth'},
  'transition': {'kind': 'crossFade', 'duration': '0.5s', 'overlap': true, 'ease': 'linear'},
  'scenes': [
    {
      'duration': '90f',
      'background': {
        'kind': 'gradient',
        'colors': ['#1A2980', '#26D0CE'],
      },
      'children': [
        {
          'type': 'Text',
          'text': 'Title',
          'style': {'color': '#FFFFFF', 'fontSize': 72, 'fontWeight': 'w700'},
          'anchor': 'intro',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f', 'ease': 'linear'},
          ],
        },
        {
          'type': 'Text',
          'text': 'Follower',
          'animate': [
            {
              'preset': 'fadeIn',
              'duration': '20f',
              'ease': 'linear',
              'at': {'kind': 'after', 'anchor': 'intro'},
            },
          ],
        },
      ],
    },
    {
      'duration': '60f',
      'background': {'kind': 'vhs'},
      'children': [
        {
          'type': 'Image',
          'source': {'kind': 'asset', 'value': 'fixtures/swatch.png'},
          'fit': 'cover',
          'animate': [
            {'preset': 'kenBurns', 'zoom': 1.2, 'pan': 'left'},
          ],
        },
      ],
    },
  ],
};

/// A media-free single-scene document for mount tests (no image/media to
/// pre-resolve): an anchored title and a follower gated on `Trigger.after`.
Map<String, Object?> _textSpecJson() => {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'background': {
        'kind': 'gradient',
        'colors': ['#1A2980', '#26D0CE'],
      },
      'children': [
        {
          'type': 'Text',
          'text': 'Title',
          'anchor': 'intro',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f', 'ease': 'linear'},
          ],
        },
        {
          'type': 'Text',
          'text': 'Follower',
          'animate': [
            {
              'preset': 'fadeIn',
              'duration': '20f',
              'ease': 'linear',
              'at': {'kind': 'after', 'anchor': 'intro'},
            },
          ],
        },
      ],
    },
  ],
};

Widget _harness(Video video, RenderController controller, TimelineProbe probe) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: controller,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TimelineProbeScope(probe: probe, child: video),
    ),
  ),
);

void main() {
  group('VideoSpec round-trip', () {
    test('re-serialization is stable (canonical idempotent form)', () {
      final once = VideoSpec.fromJson(_richSpecJson()).toJson();
      final twice = VideoSpec.fromJson(once).toJson();
      expect(twice, once);
    });

    test('preserves the document shape', () {
      final spec = VideoSpec.fromJson(_richSpecJson());
      expect(spec.size, VideoSize.square);
      expect(spec.fps, 30);
      expect(spec.scenes, hasLength(2));
      expect(spec.scenes.first.children, hasLength(2));
      expect(spec.scenes.first.children.first.anchor, 'intro');
    });
  });

  group('VideoSpec.fromJson errors', () {
    test('rejects an empty or missing scenes list', () {
      expect(() => VideoSpec.fromJson(const {}), throwsA(isA<FluvieSpecError>()));
      expect(
        () => VideoSpec.fromJson(const {'scenes': <Object?>[]}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('rejects an unsupported schema version', () {
      expect(
        () => VideoSpec.fromJson(const {'fluvieSpec': 99, 'scenes': <Object?>[]}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('locates an unknown element type at its document path', () {
      final json = {
        'scenes': [
          {
            'duration': '1s',
            'children': [
              {'type': 'Spinner'},
            ],
          },
        ],
      };
      expect(
        () => VideoSpec.fromJson(json),
        throwsA(
          isA<FluvieSpecError>().having(
            (error) => error.path,
            'path',
            ['scenes', '0', 'children', '0'],
          ),
        ),
      );
    });

    test('locates an unknown animation preset deep in the tree', () {
      final json = {
        'scenes': [
          {
            'duration': '1s',
            'children': [
              {
                'type': 'Text',
                'text': 'x',
                'animate': [
                  {'preset': 'explode'},
                ],
              },
            ],
          },
        ],
      };
      expect(
        () => VideoSpec.fromJson(json),
        throwsA(
          isA<FluvieSpecError>().having(
            (error) => error.path,
            'path',
            ['scenes', '0', 'children', '0', 'animate', '0'],
          ),
        ),
      );
    });
  });

  group('VideoSpec.digest', () {
    test('is stable for an identical spec and changes with content', () {
      final base = VideoSpec.fromJson(_richSpecJson()).digest();
      final same = VideoSpec.fromJson(_richSpecJson()).digest();
      expect(same, base);

      final edited = _richSpecJson();
      (((edited['scenes']! as List)[0] as Map)['children'] as List)[0] = {
        'type': 'Text',
        'text': 'Changed',
      };
      expect(VideoSpec.fromJson(edited).digest(), isNot(base));
    });
  });

  group('buildVideo', () {
    test('maps to a Video with the expected geometry and duration', () {
      final video = buildVideo(VideoSpec.fromJson(_richSpecJson()));
      expect(video.width, 1080);
      expect(video.height, 1080);
      expect(video.fps, 30);
      expect(video.scenes, hasLength(2));
      // 90 + 60 frames minus the 15-frame (0.5s) overlapping cross-fade.
      expect(video.totalFrames, 135);
      expect(video.sceneStartFrames, [0, 75]);
    });

    testWidgets('resolves an anchor reference that survived serialization', (tester) async {
      final probe = TimelineProbe();
      await tester.pumpWidget(
        _harness(buildVideo(VideoSpec.fromJson(_textSpecJson())), RenderController(), probe),
      );
      await tester.pump();

      final timeline = probe.value;
      expect(timeline, isNotNull);
      expect(timeline!.warnings, isEmpty);
      // The anchored title fades 0..30; the follower's Trigger.after('intro')
      // links across serialization, so it starts exactly at the title's end.
      expect(timeline.rowsFor('s0e0:intro').single.startFrame, 0);
      expect(timeline.rowsFor('s0e0:intro').single.endFrame, 30);
      expect(timeline.rowsFor('s0e1:Text').single.startFrame, 30);
      expect(timeline.rowsFor('s0e1:Text').single.endFrame, 50);
    });

    testWidgets('two mounts resolve to byte-identical timelines (determinism)', (tester) async {
      Future<String> mountAndDump() async {
        final probe = TimelineProbe();
        await tester.pumpWidget(
          _harness(buildVideo(VideoSpec.fromJson(_textSpecJson())), RenderController(), probe),
        );
        await tester.pump();
        final text = debugTimeline(probe.value!);
        await tester.pumpWidget(const SizedBox.shrink());
        return text;
      }

      expect(await mountAndDump(), await mountAndDump());
    });
  });
}
