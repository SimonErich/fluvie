import 'dart:typed_data';

import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// The web side of the `readFileBytes` seam: a browser render has no file
/// system, so `file://` media fails with a clear typed error pointing at the
/// supported source kinds.
Future<Uint8List> readFileBytes(String path) async {
  throw FluvieRenderException(
    'file:// media sources are not supported on web (got "$path"); use an '
    'asset, network, or memory source instead.',
  );
}
