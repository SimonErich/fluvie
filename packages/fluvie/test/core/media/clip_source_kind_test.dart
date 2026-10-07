import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/clip_source_kind.dart';
import 'package:fluvie/src/core/media/media_source.dart';

void main() {
  group('isClipSource', () {
    test('classifies path-shaped sources by extension', () {
      expect(isClipSource(const MediaSource.file('/v.mp4')), isTrue);
      expect(isClipSource(const MediaSource.asset('clips/take.mov')), isTrue);
      expect(isClipSource(MediaSource.network(Uri.parse('https://x/v.webm'))), isTrue);
      expect(isClipSource(const MediaSource.file('/photo.png')), isFalse);
      expect(isClipSource(const MediaSource.asset('img.jpg')), isFalse);
    });

    test('classifies a memory source by its debug label', () {
      final bytes = Uint8List.fromList(const [1, 2, 3]);
      expect(isClipSource(MediaSource.memory(bytes, debugLabel: 'media/cam.mp4')), isTrue);
      expect(isClipSource(MediaSource.memory(bytes, debugLabel: 'take.MOV')), isTrue);
      expect(isClipSource(MediaSource.memory(bytes, debugLabel: 'media/photo.png')), isFalse);
    });

    test('an unlabelled memory source stays an image', () {
      expect(isClipSource(MediaSource.memory(Uint8List(0))), isFalse);
    });
  });
}
