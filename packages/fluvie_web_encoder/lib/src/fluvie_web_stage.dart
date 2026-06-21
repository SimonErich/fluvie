// coverage:ignore-file: drives the live engine pipeline (post-frame callbacks,
// scheduleFrame, off-screen paint) so a real RepaintBoundary mounts and reads
// back; this only runs in a browser, not the unit-test binding. The renderer
// orchestration is covered with a tester-backed host, and the full chain is
// proven by the headless-Chrome end-to-end render.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fluvie_web_encoder/src/web_capture_host.dart';

/// Wrap your app's root in a [FluvieWebStage] to enable in-browser rendering.
///
/// In-browser capture reads pixels back from a [RepaintBoundary] the engine has
/// actually painted, so the capture surface must live inside the running app's
/// own pipeline (a standalone off-screen pipeline never mounts the boundary).
/// [FluvieWebStage] provides that surface: it shows [child] normally and keeps a
/// hidden slot, parked far off-screen but still painted, where the renderer
/// mounts each composition while it captures. Nothing ever appears on screen.
///
/// ```dart
/// void main() => runApp(const FluvieWebStage(child: MyApp()));
/// ```
///
/// With a stage mounted, `WebVideoRenderer().render(...)` works with no further
/// wiring — it captures through the active stage by default. Without one, the
/// renderer throws a [StateError] that explains this.
final class FluvieWebStage extends StatefulWidget {
  /// Wraps [child], adding the hidden capture surface in the same pipeline.
  const FluvieWebStage({required this.child, super.key});

  /// The app shown on screen.
  final Widget child;

  /// A [WebCaptureHost] bound to the currently-mounted stage, sized to [size].
  ///
  /// `WebVideoRenderer` uses this by default. The host throws a clear
  /// [StateError] if no [FluvieWebStage] is mounted when capture begins.
  static WebCaptureHost hostFor(Size size) => _StageCaptureHost(size);

  @override
  State<FluvieWebStage> createState() => _FluvieWebStageState();
}

class _FluvieWebStageState extends State<FluvieWebStage> {
  /// The most recently mounted stage — the one the default host captures into.
  static _FluvieWebStageState? active;

  final ValueNotifier<Widget?> _slot = ValueNotifier<Widget?>(null);

  @override
  void initState() {
    super.initState();
    active = this;
  }

  @override
  void dispose() {
    if (identical(active, this)) active = null;
    _slot.dispose();
    super.dispose();
  }

  Future<void> show(Widget tree, Size size) {
    _slot.value = SizedBox(width: size.width, height: size.height, child: tree);
    return pump();
  }

  Future<void> pump() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    WidgetsBinding.instance.scheduleFrame();
    return completer.future;
  }

  void hide() => _slot.value = null;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: widget.child),
          // Painted (so the capture boundary reads back real pixels) but parked
          // far off-screen, so the user never sees the frame being captured.
          Positioned(
            left: -100000,
            top: 0,
            child: ValueListenableBuilder<Widget?>(
              valueListenable: _slot,
              builder: (_, tree, _) => tree ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The default [WebCaptureHost]: mounts each composition into the active
/// [FluvieWebStage] (the app's own pipeline, off-screen) and pumps the engine.
final class _StageCaptureHost implements WebCaptureHost {
  _StageCaptureHost(this.size);

  /// The render resolution in logical pixels.
  final Size size;

  _FluvieWebStageState? _bound;

  @override
  Future<void> mount(Widget tree) {
    final stage = _FluvieWebStageState.active;
    if (stage == null) {
      throw StateError(
        'No FluvieWebStage is mounted. Wrap your app root in a FluvieWebStage so '
        'in-browser rendering has a capture surface: '
        'runApp(FluvieWebStage(child: MyApp())).',
      );
    }
    _bound = stage;
    return stage.show(tree, size);
  }

  @override
  Future<void> pumpFrame() => _bound!.pump();

  @override
  Future<void> dispose() async => _bound?.hide();
}
