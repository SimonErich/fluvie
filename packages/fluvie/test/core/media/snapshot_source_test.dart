import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';

void main() {
  const viewport = SnapshotViewport(width: 800, height: 600);

  group('SnapshotSource factories carry their request', () {
    test('mermaid wraps a mermaid request', () {
      const source = SnapshotSource.mermaid('graph TD; A-->B', themeKey: 'dark');
      expect(source, isA<MermaidSnapshotSource>());
      expect(source.request, const SnapshotRequest.mermaid('graph TD; A-->B', themeKey: 'dark'));
    });

    test('html wraps an html request', () {
      const source = SnapshotSource.html('<p>hi</p>', viewport: viewport);
      expect(source, isA<HtmlSnapshotSource>());
      expect(source.request, const SnapshotRequest.html('<p>hi</p>', viewport: viewport));
    });

    test('url wraps a url request and exposes the host', () {
      final source = SnapshotSource.url(Uri.parse('https://example.com/p'), viewport: viewport);
      expect(source, isA<UrlSnapshotSource>());
      expect((source as UrlSnapshotSource).host, 'example.com');
    });
  });

  group('SnapshotSource value equality', () {
    test('mermaid == mermaid for the same source and theme', () {
      expect(
        const SnapshotSource.mermaid('g', themeKey: 'dark'),
        const SnapshotSource.mermaid('g', themeKey: 'dark'),
      );
      expect(
        const SnapshotSource.mermaid('g', themeKey: 'dark').hashCode,
        const SnapshotSource.mermaid('g', themeKey: 'dark').hashCode,
      );
    });

    test('mermaid differs when the theme key differs', () {
      expect(
        const SnapshotSource.mermaid('g', themeKey: 'dark'),
        isNot(const SnapshotSource.mermaid('g', themeKey: 'light')),
      );
    });

    test('html differs when the viewport differs', () {
      expect(
        const SnapshotSource.html('x', viewport: viewport),
        isNot(const SnapshotSource.html('x', viewport: SnapshotViewport(width: 801, height: 600))),
      );
    });
  });

  group('SnapshotSource.cacheKey', () {
    test('is stable across identical sources', () {
      const a = SnapshotSource.mermaid('g', themeKey: 'dark');
      const b = SnapshotSource.mermaid('g', themeKey: 'dark');
      expect(a.cacheKey, b.cacheKey);
    });

    test('distinguishes a theme change', () {
      expect(
        const SnapshotSource.mermaid('g', themeKey: 'dark').cacheKey,
        isNot(const SnapshotSource.mermaid('g', themeKey: 'light').cacheKey),
      );
    });

    test('distinguishes a viewport change', () {
      expect(
        const SnapshotSource.html('x', viewport: viewport).cacheKey,
        isNot(
          const SnapshotSource.html(
            'x',
            viewport: SnapshotViewport(width: 801, height: 600),
          ).cacheKey,
        ),
      );
    });

    test('distinguishes mermaid from html with the same payload', () {
      expect(
        const SnapshotSource.mermaid('x').cacheKey,
        isNot(const SnapshotSource.html('x', viewport: viewport).cacheKey),
      );
    });

    test('is a path-safe hex string (fnv1a64Hex)', () {
      final key = const SnapshotSource.mermaid('g').cacheKey;
      expect(key, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('distinguishes an html source-text change', () {
      expect(
        const SnapshotSource.html('a', viewport: viewport).cacheKey,
        isNot(const SnapshotSource.html('b', viewport: viewport).cacheKey),
      );
    });
  });

  group('UrlSnapshotSource', () {
    UrlSnapshotSource urlSource({
      String uri = 'https://example.com/p',
      SnapshotViewport vp = viewport,
      int scrollX = 0,
      int scrollY = 0,
      int? clipWidth,
      int? clipHeight,
    }) => UrlSnapshotSource(
      Uri.parse(uri),
      viewport: vp,
      scrollX: scrollX,
      scrollY: scrollY,
      clipWidth: clipWidth,
      clipHeight: clipHeight,
    );

    test('two identical sources are ==, share a cacheKey and a hashCode', () {
      final a = urlSource(scrollX: 10, scrollY: 20, clipWidth: 100, clipHeight: 50);
      final b = urlSource(scrollX: 10, scrollY: 20, clipWidth: 100, clipHeight: 50);
      expect(a, b);
      expect(a.cacheKey, b.cacheKey);
      expect(a.hashCode, b.hashCode);
    });

    test('cacheKey distinguishes a scrollX change', () {
      expect(urlSource().cacheKey, isNot(urlSource(scrollX: 1).cacheKey));
    });

    test('cacheKey distinguishes a scrollY change', () {
      expect(urlSource().cacheKey, isNot(urlSource(scrollY: 1).cacheKey));
    });

    test('cacheKey distinguishes a clipWidth change', () {
      expect(urlSource().cacheKey, isNot(urlSource(clipWidth: 10).cacheKey));
    });

    test('cacheKey distinguishes a clipHeight change', () {
      expect(urlSource().cacheKey, isNot(urlSource(clipHeight: 10).cacheKey));
    });

    test('cacheKey distinguishes a viewport change', () {
      expect(
        urlSource().cacheKey,
        isNot(urlSource(vp: const SnapshotViewport(width: 801, height: 600)).cacheKey),
      );
    });

    test('cacheKey distinguishes a uri change', () {
      expect(
        urlSource().cacheKey,
        isNot(urlSource(uri: 'https://example.com/other').cacheKey),
      );
    });

    test('request carries the matching UrlRequest fields', () {
      final source = urlSource(scrollX: 10, scrollY: 20, clipWidth: 100, clipHeight: 50);
      final request = source.request;
      expect(request, isA<UrlRequest>());
      final url = request as UrlRequest;
      expect(url.uri, Uri.parse('https://example.com/p'));
      expect(url.viewport, viewport);
      expect(url.scrollX, 10);
      expect(url.scrollY, 20);
      expect(url.clipWidth, 100);
      expect(url.clipHeight, 50);
    });

    test('toString contains the uri', () {
      expect(urlSource().toString(), contains('https://example.com/p'));
    });
  });
}
