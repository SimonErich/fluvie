import 'package:flutter/widgets.dart' show Widget;

/// Mounts the capture shell using a host's ordinary Flutter element tree.
typedef ShellMount = Future<void> Function(Widget tree);

/// Flushes a sought composition frame before its pixels are captured.
typedef ShellFramePump = Future<void> Function();

/// Applies the captured canvas dimensions to a host view.
typedef SetViewSize = void Function(int width, int height);

/// Runs IO and rasterization outside a test host's fake event loop.
typedef ShellRunAsync = Future<T?> Function<T>(Future<T> Function() callback);

/// Executes a callback on a host that already has a real event loop.
Future<T?> runAsyncDirectly<T>(Future<T> Function() callback) => callback();
