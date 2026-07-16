import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';
import 'package:window_manager/window_manager.dart';

/// Creates the IO-platform controller: immersive mode on mobile, the window
/// on desktop.
FullscreenController createFullscreenController() => IoFullscreenController();

/// The desktop window seam, so the controller is testable without a real
/// window: the default forwards to `window_manager`.
abstract interface class DesktopWindowBridge {
  /// Sets the window's fullscreen state.
  Future<void> setFullScreen({required bool fullscreen});

  /// Reads the window's fullscreen state.
  Future<bool> isFullScreen();
}

final class _WindowManagerBridge implements DesktopWindowBridge {
  const _WindowManagerBridge();

  // coverage:ignore-start thin window_manager adapter needing a real desktop window the controller logic is covered through the fake bridge
  @override
  Future<void> setFullScreen({required bool fullscreen}) async {
    await windowManager.ensureInitialized();
    await windowManager.setFullScreen(fullscreen);
  }

  @override
  Future<bool> isFullScreen() async {
    await windowManager.ensureInitialized();
    return windowManager.isFullScreen();
  }

  // coverage:ignore-end
}

/// Fullscreen on IO platforms: mobile flips `SystemChrome` UI modes
/// (immersive-sticky in, edge-to-edge out) and tracks the state itself —
/// the system has no query — while desktop drives the window through the
/// [DesktopWindowBridge].
final class IoFullscreenController extends FullscreenController {
  /// Creates the controller; [desktop] defaults to the `window_manager`
  /// bridge.
  IoFullscreenController({DesktopWindowBridge? desktop})
    : _desktop = desktop ?? const _WindowManagerBridge();

  final DesktopWindowBridge _desktop;
  bool _mobileFullscreen = false;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<void> enter() async {
    if (_isMobile) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _mobileFullscreen = true;
    } else {
      await _desktop.setFullScreen(fullscreen: true);
    }
  }

  @override
  Future<void> exit() async {
    if (_isMobile) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _mobileFullscreen = false;
    } else {
      await _desktop.setFullScreen(fullscreen: false);
    }
  }

  @override
  Future<bool> get isFullscreen async => _isMobile ? _mobileFullscreen : _desktop.isFullScreen();
}
