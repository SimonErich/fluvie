import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller_stub.dart'
    if (dart.library.js_interop) 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller_web.dart'
    if (dart.library.io) 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller_io.dart';

/// Platform fullscreen behind one interface: the Fullscreen API on the web,
/// the window on desktop, immersive mode on mobile.
///
/// Implementations are picked by conditional import through
/// [createFullscreenController]; tests override
/// [fullscreenControllerProvider] with a fake.
abstract base class FullscreenController {
  /// The shared toggle contract.
  const FullscreenController();

  /// Enters fullscreen. On the web this must happen inside a user gesture.
  Future<void> enter();

  /// Leaves fullscreen.
  Future<void> exit();

  /// Whether the presenter is currently fullscreen.
  Future<bool> get isFullscreen;

  /// Enters or leaves, based on [isFullscreen].
  Future<void> toggle() async => await isFullscreen ? exit() : enter();
}

/// The fullscreen controller for platforms with nothing to control (and for
/// tests that don't care): every call is a no-op and the state is never
/// fullscreen.
final class NoopFullscreenController extends FullscreenController {
  /// Creates the no-op controller.
  const NoopFullscreenController();

  @override
  Future<void> enter() async {}

  @override
  Future<void> exit() async {}

  @override
  Future<bool> get isFullscreen async => false;
}

/// The platform's fullscreen controller.
final fullscreenControllerProvider = Provider<FullscreenController>(
  (ref) => createFullscreenController(),
);
