import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// Reads the bytes of the file at [path] — the native (`dart:io`) side of the
/// `readFileBytes` seam.
///
/// Throws a typed [FluvieRenderException] when the file is missing; any read
/// failure propagates raw so the caller can wrap it with its own context.
Future<Uint8List> readFileBytes(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw FluvieRenderException('Media file "$path" does not exist.');
  }
  return file.readAsBytes();
}
