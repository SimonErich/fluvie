import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/media_source.dart';

void main() {
  group('MediaSource factories carry their fields', () {
    test('asset carries the bundle key', () {
      const source = MediaSource.asset('fixtures/swatch.png');
      expect(source, isA<AssetSource>());
      expect((source as AssetSource).name, 'fixtures/swatch.png');
    });

    test('file carries the path', () {
      const source = MediaSource.file('/tmp/photo.png');
      expect(source, isA<FileSource>());
      expect((source as FileSource).path, '/tmp/photo.png');
    });

    test('network carries the url', () {
      final url = Uri.parse('https://example.com/clip.mp4');
      final source = MediaSource.network(url);
      expect(source, isA<NetworkSource>());
      expect((source as NetworkSource).url, url);
    });

    test('memory carries the bytes and optional label', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final source = MediaSource.memory(bytes, debugLabel: 'swatch');
      expect(source, isA<MemorySource>());
      expect((source as MemorySource).bytes, same(bytes));
      expect(source.debugLabel, 'swatch');
    });
  });

  group('MediaSource value equality', () {
    test('asset == asset for the same name', () {
      expect(const MediaSource.asset('a.png'), const MediaSource.asset('a.png'));
      expect(const MediaSource.asset('a.png').hashCode, const MediaSource.asset('a.png').hashCode);
    });

    test('asset != asset for a different name', () {
      expect(const MediaSource.asset('a.png'), isNot(const MediaSource.asset('b.png')));
    });

    test('file == file for the same path', () {
      expect(const MediaSource.file('/p.png'), const MediaSource.file('/p.png'));
    });

    test('network == network for the same url', () {
      final url = Uri.parse('https://example.com/x.png');
      expect(MediaSource.network(url), MediaSource.network(Uri.parse('https://example.com/x.png')));
    });

    test('memory equals by bytes identity and label', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(
        MediaSource.memory(bytes, debugLabel: 'a'),
        MediaSource.memory(bytes, debugLabel: 'a'),
      );
      expect(
        MediaSource.memory(bytes, debugLabel: 'a'),
        isNot(MediaSource.memory(bytes, debugLabel: 'b')),
      );
      expect(
        MediaSource.memory(bytes),
        isNot(MediaSource.memory(Uint8List.fromList([1, 2, 3]))),
        reason: 'memory equality is by bytes identity, not contents',
      );
      // Equal memory sources agree on hashCode (same bytes identity + label).
      expect(
        MediaSource.memory(bytes, debugLabel: 'a').hashCode,
        MediaSource.memory(bytes, debugLabel: 'a').hashCode,
      );
    });

    test('different kinds with similar payloads are never equal', () {
      expect(const MediaSource.asset('x'), isNot(const MediaSource.file('x')));
      expect(
        MediaSource.network(Uri.parse('https://x')),
        isNot(const MediaSource.asset('https://x')),
      );
    });
  });

  group('MediaSource.toString names the source', () {
    test('asset', () {
      expect(const MediaSource.asset('logo.png').toString(), contains('logo.png'));
      expect(const MediaSource.asset('logo.png').toString(), contains('asset'));
    });

    test('file', () {
      expect(const MediaSource.file('/tmp/a.png').toString(), contains('/tmp/a.png'));
    });

    test('network', () {
      expect(
        MediaSource.network(Uri.parse('https://example.com/c.mp4')).toString(),
        contains('https://example.com/c.mp4'),
      );
    });

    test('memory names the label and byte count', () {
      final s = MediaSource.memory(Uint8List.fromList([1, 2, 3]), debugLabel: 'tiny');
      expect(s.toString(), contains('tiny'));
      expect(s.toString(), contains('3'));
    });
  });

  test('const asset/file are canonicalized', () {
    const a = MediaSource.asset('x.png');
    const b = MediaSource.asset('x.png');
    expect(identical(a, b), isTrue);
  });
}
