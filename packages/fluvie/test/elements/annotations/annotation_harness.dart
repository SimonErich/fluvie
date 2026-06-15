import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// A 30-fps scope starting at frame 0 with a 60-frame window — the clock every
/// draw-on annotation resolves its reveal against.
const TimeScopeData _scope = TimeScopeData(fps: 30, startFrame: 0, durationFrames: 60);

/// Wraps [child] in the minimal scopes a frame-driven annotation needs: a
/// directionality, a render mode, the frame clock, and a time scope.
Widget wrapScoped(Widget child, {int frame = 0, RenderMode mode = RenderMode.preview}) {
  return RenderModeContext(
    mode: mode,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: FrameProvider(
        frame: frame,
        child: TimeScopeProvider(
          scope: _scope,
          child: SizedBox(width: 100, height: 100, child: child),
        ),
      ),
    ),
  );
}

/// Pumps [annotation] under the annotation scopes at [frame], optionally
/// wrapping it once more via [wrap] (e.g. a `FluvieTokensScope`).
Future<void> pumpAnnotation(
  WidgetTester tester,
  Widget annotation, {
  int frame = 0,
  RenderMode mode = RenderMode.preview,
  Widget Function(Widget child)? wrap,
}) async {
  final child = wrap == null ? annotation : wrap(annotation);
  await tester.pumpWidget(wrapScoped(child, frame: frame, mode: mode));
}
