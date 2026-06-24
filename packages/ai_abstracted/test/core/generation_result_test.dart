import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('GenerationResult', () {
    final bytes = Uint8List.fromList(utf8.encode('hello'));
    const metadata = GenerationMetadata(model: 'm');

    test('exposes its fields', () {
      final result = GenerationResult(
        bytes: bytes,
        mimeType: 'text/plain',
        kind: MediaKind.text,
        metadata: metadata,
        seedUsed: '42',
      );
      expect(result.bytes, bytes);
      expect(result.mimeType, 'text/plain');
      expect(result.kind, MediaKind.text);
      expect(result.metadata, same(metadata));
      expect(result.seedUsed, '42');
    });

    test('seedUsed defaults to null', () {
      final result = GenerationResult(
        bytes: bytes,
        mimeType: 'text/plain',
        kind: MediaKind.text,
        metadata: metadata,
      );
      expect(result.seedUsed, isNull);
    });

    test('text decodes the bytes as utf8', () {
      final result = GenerationResult(
        bytes: bytes,
        mimeType: 'text/plain',
        kind: MediaKind.text,
        metadata: metadata,
      );
      expect(result.text, 'hello');
    });
  });
}
