import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/media/net/network_allowlist.dart';

void main() {
  group('NetworkAllowlist.check', () {
    test('an allowed host over an allowed scheme passes', () {
      const allowlist = NetworkAllowlist(hosts: {'example.com'});
      expect(
        () => allowlist.check(Uri.parse('https://example.com/clip.mp4')),
        returnsNormally,
      );
    });

    test('a disallowed host throws naming it', () {
      const allowlist = NetworkAllowlist(hosts: {'example.com'});
      expect(
        () => allowlist.check(Uri.parse('https://evil.test/clip.mp4')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('evil.test')),
        ),
      );
    });

    test('a disallowed scheme throws naming it', () {
      const allowlist = NetworkAllowlist(hosts: {'example.com'});
      expect(
        () => allowlist.check(Uri.parse('ftp://example.com/clip.mp4')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('ftp')),
        ),
      );
    });

    test('http is rejected unless configured', () {
      const httpsOnly = NetworkAllowlist(hosts: {'example.com'});
      expect(
        () => httpsOnly.check(Uri.parse('http://example.com/clip.mp4')),
        throwsA(isA<FluvieRenderException>()),
      );

      const withHttp = NetworkAllowlist(
        hosts: {'example.com'},
        schemes: {'http', 'https'},
      );
      expect(
        () => withHttp.check(Uri.parse('http://example.com/clip.mp4')),
        returnsNormally,
      );
    });

    test('the default schemes are https only', () {
      const allowlist = NetworkAllowlist(hosts: {'example.com'});
      expect(allowlist.schemes, const {'https'});
    });

    test('allowAny lets every host through over the allowed schemes', () {
      final allowlist = NetworkAllowlist.allowAny();
      expect(() => allowlist.check(Uri.parse('https://anywhere.test/x')), returnsNormally);
      expect(
        () => allowlist.check(Uri.parse('ftp://anywhere.test/x')),
        throwsA(isA<FluvieRenderException>()),
      );
    });

    test('a missing host throws', () {
      const allowlist = NetworkAllowlist(hosts: {'example.com'});
      expect(
        () => allowlist.check(Uri.parse('https:///path')),
        throwsA(isA<FluvieRenderException>()),
      );
    });
  });
}
