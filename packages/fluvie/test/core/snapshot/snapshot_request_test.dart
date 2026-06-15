import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';

void main() {
  const viewport = SnapshotViewport(width: 800, height: 600);

  group('SnapshotRequest.mermaid', () {
    test('carries the source and optional theme key', () {
      const request = SnapshotRequest.mermaid('graph TD; A-->B', themeKey: 'dark');
      expect(request, isA<MermaidRequest>());
      expect((request as MermaidRequest).source, 'graph TD; A-->B');
      expect(request.themeKey, 'dark');
    });

    test('is value-equal across identical fields', () {
      expect(
        const SnapshotRequest.mermaid('g', themeKey: 'dark'),
        const SnapshotRequest.mermaid('g', themeKey: 'dark'),
      );
    });

    test('differs when the source or theme key differ', () {
      const base = SnapshotRequest.mermaid('g', themeKey: 'dark');
      expect(base, isNot(const SnapshotRequest.mermaid('h', themeKey: 'dark')));
      expect(base, isNot(const SnapshotRequest.mermaid('g', themeKey: 'light')));
    });
  });

  group('SnapshotRequest.html', () {
    test('carries the source and viewport', () {
      const request = SnapshotRequest.html('<p>hi</p>', viewport: viewport);
      expect(request, isA<HtmlRequest>());
      expect((request as HtmlRequest).source, '<p>hi</p>');
      expect(request.viewport, viewport);
    });

    test('differs when the viewport differs', () {
      const a = SnapshotRequest.html('x', viewport: viewport);
      const b = SnapshotRequest.html('x', viewport: SnapshotViewport(width: 801, height: 600));
      expect(a, isNot(b));
    });

    test('two identical requests share a hashCode', () {
      expect(
        const SnapshotRequest.html('<p>hi</p>', viewport: viewport).hashCode,
        const SnapshotRequest.html('<p>hi</p>', viewport: viewport).hashCode,
      );
    });

    test('toString reports the source length and viewport', () {
      final text = const SnapshotRequest.html('<p>hi</p>', viewport: viewport).toString();
      expect(text, contains('html'));
      expect(text, contains('800'));
    });
  });

  group('SnapshotRequest.url', () {
    test('carries the uri, viewport, scroll and clip', () {
      final uri = Uri.parse('https://example.com');
      final request = SnapshotRequest.url(
        uri,
        viewport: viewport,
        scrollX: 10,
        scrollY: 20,
        clipWidth: 100,
        clipHeight: 50,
      );
      expect(request, isA<UrlRequest>());
      final url = request as UrlRequest;
      expect(url.uri, uri);
      expect(url.viewport, viewport);
      expect(url.scrollX, 10);
      expect(url.scrollY, 20);
      expect(url.clipWidth, 100);
      expect(url.clipHeight, 50);
    });

    test('is value-equal across identical fields', () {
      final uri = Uri.parse('https://example.com');
      expect(
        SnapshotRequest.url(uri, viewport: viewport),
        SnapshotRequest.url(Uri.parse('https://example.com'), viewport: viewport),
      );
    });

    test('differs when scroll differs', () {
      final uri = Uri.parse('https://example.com');
      expect(
        SnapshotRequest.url(uri, viewport: viewport),
        isNot(SnapshotRequest.url(uri, viewport: viewport, scrollY: 5)),
      );
    });

    test('two identical requests share a hashCode', () {
      final uri = Uri.parse('https://example.com');
      expect(
        SnapshotRequest.url(uri, viewport: viewport, scrollX: 1, clipWidth: 9).hashCode,
        SnapshotRequest.url(
          Uri.parse('https://example.com'),
          viewport: viewport,
          scrollX: 1,
          clipWidth: 9,
        ).hashCode,
      );
    });

    test('toString contains the uri', () {
      final uri = Uri.parse('https://example.com/page');
      expect(SnapshotRequest.url(uri, viewport: viewport).toString(), contains(uri.toString()));
    });
  });
}
