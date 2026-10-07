// The show-window render pin: an element carrying `show: {from, to}` must
// appear and disappear at the authored frames, and the spec form must render
// identically to the `.show()` widget sugar. Each row mounts the widget and
// spec builds side by side at one frame: before `from` and after `to` only
// the always-on reference box paints; inside the window the windowed box
// joins it. If either half shows the windowed box outside 30..60, or the
// halves diverge, the golden fails.
@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/placement.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/elements/placed.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

const _width = 240.0;
const _height = 180.0;

/// The spec side: a windowed overlay exactly as an editor writes it.
Map<String, Object?> _specDocument() => {
  'fluvieSpec': 1,
  'size': {'width': 240, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#101018'},
      'children': [
        {
          'type': 'Box',
          'color': '#6C5CE7',
          'transform': {'x': 0.5, 'y': 0.4, 'w': 0.5, 'h': 0.4},
          'show': {'from': '30f', 'to': '60f'},
        },
        {
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.5, 'y': 0.85, 'w': 0.7, 'h': 0.12},
        },
      ],
    },
  ],
};

/// The widget side: the same video authored with the `.show()` sugar the
/// spec's `show` key desugars to.
Video _widgetVideo() => Video(
  size: const VideoSize(240, 180),
  scenes: [
    Scene(
      duration: const Time.frames(90),
      background: Background.color(const Color(0xFF101018)),
      children: [
        Placed(
          placement: const Placement(x: 0.5, y: 0.4, width: 0.5, height: 0.4),
          child: const Box(
            color: Color(0xFF6C5CE7),
          ).show(from: const Time.frames(30), to: const Time.frames(60)),
        ),
        const Placed(
          placement: Placement(x: 0.5, y: 0.85, width: 0.7, height: 0.12),
          child: Box(color: Color(0xFF2ECC8F)),
        ),
      ],
    ),
  ],
);

Widget _mounted(Widget video, {required int frame}) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: RenderController(initialFrame: frame),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: _width, height: _height, child: video),
    ),
  ),
);

Future<void> main() async {
  await goldenTest(
    'a show window appears and disappears at the authored frames',
    fileName: 'show_window_equivalence',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final frame in const [15, 45, 75]) ...[
          GoldenTestScenario(
            name: 'widgets, frame $frame',
            child: _mounted(_widgetVideo(), frame: frame),
          ),
          GoldenTestScenario(
            name: 'from spec, frame $frame',
            child: _mounted(VideoSpec.fromJson(_specDocument()).build(), frame: frame),
          ),
        ],
      ],
    ),
  );
}
