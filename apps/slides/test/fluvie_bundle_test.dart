import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slides/loader/fluvie_bundle.dart';

Uint8List _zipOf(Map<String, Object> entries) {
  final archive = Archive();
  entries.forEach((name, content) {
    archive.addFile(
      content is String
          ? ArchiveFile.string(name, content)
          : ArchiveFile.bytes(name, content as List<int>),
    );
  });
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  const deckJson = '{"fluvieSpec": 1}';
  final photo = Uint8List.fromList(List<int>.generate(64, (i) => i));

  group('isZipBytes', () {
    test('sniffs the PK magic and nothing else', () {
      expect(isZipBytes(_zipOf({fluvieBundleDeckName: deckJson})), isTrue);
      expect(isZipBytes(utf8.encode('{"fluvieSpec": 1}')), isFalse);
      expect(isZipBytes(const []), isFalse);
      expect(isZipBytes(const [0x50]), isFalse);
    });
  });

  group('buildFluvieBundle and readFluvieBundle', () {
    test('round-trip: the deck JSON and every media byte come back identical', () {
      final bytes = buildFluvieBundle(
        deckJson: deckJson,
        media: {'media/photo.png': photo},
      );
      expect(isZipBytes(bytes), isTrue);
      final read = readFluvieBundle(bytes);
      expect(read.deckJson, deckJson);
      expect(read.media, hasLength(1));
      expect(read.media['media/photo.png'], photo);
    });

    test('a bundle without the deck JSON is rejected', () {
      expect(
        () => readFluvieBundle(_zipOf({'media/x.png': photo})),
        throwsA(isA<FluvieBundleException>()),
      );
    });

    test('an entry outside media/ is rejected', () {
      expect(
        () => readFluvieBundle(
          _zipOf({fluvieBundleDeckName: deckJson, 'other/x.bin': photo}),
        ),
        throwsA(
          isA<FluvieBundleException>().having(
            (e) => e.message,
            'message',
            contains('other/x.bin'),
          ),
        ),
      );
    });

    test('zip-slip names are rejected before any inflation', () {
      // A trailing-slash name decodes as a directory entry and is skipped;
      // these decode as files and must be refused by name.
      for (final evil in ['media/../../etc/passwd', '/etc/passwd', r'media\..\evil']) {
        expect(
          () => readFluvieBundle(_zipOf({fluvieBundleDeckName: deckJson, evil: photo})),
          throwsA(isA<FluvieBundleException>()),
          reason: evil,
        );
      }
    });

    test('per-entry and total size caps bound the unpack', () {
      final bundle = _zipOf({fluvieBundleDeckName: deckJson, 'media/big.bin': photo});
      expect(
        () => readFluvieBundle(bundle, entryCap: 16),
        throwsA(isA<FluvieBundleException>()),
      );
      final two = _zipOf({
        fluvieBundleDeckName: deckJson,
        'media/a.bin': photo,
        'media/b.bin': photo,
      });
      expect(
        () => readFluvieBundle(two, totalCap: 100),
        throwsA(isA<FluvieBundleException>()),
      );
      expect(readFluvieBundle(two).media, hasLength(2));
    });

    test('a corrupt zip is a bundle error, not a crash', () {
      final broken = Uint8List.fromList([0x50, 0x4B, 1, 2, 3, 4]);
      expect(() => readFluvieBundle(broken), throwsA(isA<FluvieBundleException>()));
    });
  });
}
