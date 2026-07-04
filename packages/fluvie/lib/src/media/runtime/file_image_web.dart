import 'package:flutter/widgets.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// The web side of the live-preview seam: a browser has no file system, so a
/// `file://` image preview fails clearly. Capture never reaches it; it exists
/// so `resolved_image.dart` compiles without `dart:io` on web.
// coverage:ignore-start: web-only conditional-import arm; the VM test suite never loads it
Widget fileImagePreview(String path, BoxFit? fit) => throw FluvieRenderException(
  'file:// image previews are not supported on web (got "$path").',
);
// coverage:ignore-end
