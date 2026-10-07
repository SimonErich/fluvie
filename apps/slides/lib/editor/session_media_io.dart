import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie/fluvie.dart' show AudioSource, MediaSource;
import 'package:slides/editor/session_sources.dart';

/// The desktop materializer factory: session entries become real files under
/// one sandboxed temp [directory] (a fresh `fluvie_session_*` directory when
/// none is given), so the render pipeline reads honest paths.
SessionMaterializer sessionMaterializerFor({String? directory}) {
  Directory? base;
  return (String value, Uint8List bytes) async {
    base ??= directory != null
        ? await Directory(directory).create(recursive: true)
        : await Directory.systemTemp.createTemp('fluvie_session_');
    final file = File('${base!.path}/$value');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return (media: MediaSource.file(file.path), audio: AudioSource.file(file.path));
  };
}

/// The platform default: the temp-file materializer.
SessionMaterializer platformSessionMaterializer() => sessionMaterializerFor();
