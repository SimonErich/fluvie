import 'dart:io';

import 'package:slides/loader/open_fluvie_file.dart';

/// Desktop by-path open: read the file's bytes and parse them like any other
/// open (the byte sniff decides bundle against plain JSON).
Future<LoadedDeck> platformOpenFluvieFileAtPath(String path) async {
  final name = path.split(Platform.pathSeparator).last;
  final List<int> bytes;
  try {
    bytes = await File(path).readAsBytes();
  } on IOException catch (error) {
    return LoadedDeck.failed(name, 'The file could not be read: $error', path: path);
  }
  return parseFluvieBytes(name, bytes, path: path);
}
