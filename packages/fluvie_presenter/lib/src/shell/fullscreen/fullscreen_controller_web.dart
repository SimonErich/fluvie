import 'dart:js_interop';

import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';
import 'package:web/web.dart' as web;

/// Creates the web controller over the browser Fullscreen API.
FullscreenController createFullscreenController() => const WebFullscreenController();

// coverage:ignore-start browser bindings the VM coverage run never loads this library and the logic maps directly onto the Fullscreen API

/// Fullscreen on the web: the document element enters, the document exits,
/// and `fullscreenElement` answers the state. The browser only honors
/// [enter] from inside a user gesture (a key or tap handler — which is
/// where the presenter calls it from).
final class WebFullscreenController extends FullscreenController {
  /// Creates the controller.
  const WebFullscreenController();

  @override
  Future<void> enter() async {
    final root = web.document.documentElement;
    if (root == null) return;
    await root.requestFullscreen().toDart;
  }

  @override
  Future<void> exit() async {
    if (web.document.fullscreenElement == null) return;
    await web.document.exitFullscreen().toDart;
  }

  @override
  Future<bool> get isFullscreen async => web.document.fullscreenElement != null;
}

// coverage:ignore-end
