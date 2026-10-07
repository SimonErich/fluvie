import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:slides/editor/slide_image_exporter.dart';

// coverage:ignore-start the real folder dialog needs a live platform channel

/// The desktop exporter: one folder pick, then numbered PNG files inside.
SlideImageExporter platformSlideImageExporter() => _DesktopSlideImageExporter();

final class _DesktopSlideImageExporter implements SlideImageExporter {
  @override
  Future<String?> saveImages({required String baseName, required List<Uint8List> images}) async {
    final directory = await FilePicker.getDirectoryPath(dialogTitle: 'Export slide images');
    if (directory == null) return null;
    for (var slide = 0; slide < images.length; slide++) {
      final name = slideImageFileName(baseName, slide, images.length);
      await File('$directory${Platform.pathSeparator}$name').writeAsBytes(images[slide]);
    }
    return directory;
  }
}

// coverage:ignore-end
