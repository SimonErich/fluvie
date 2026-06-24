// Selects the platform default: the dart:io process/API launcher on native,
// the web-safe API launcher on web. The web variant never pulls in dart:io.
import 'package:fluvie_example/inspector/render_backend_io.dart'
    if (dart.library.html) 'package:fluvie_example/inspector/render_backend_web.dart'
    as backend;
import 'package:fluvie_example/inspector/render_launcher.dart';

/// The default [RenderLauncher] for the current platform and configuration.
RenderLauncher createRenderLauncher() => backend.createRenderLauncher();
