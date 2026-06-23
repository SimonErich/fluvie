import 'dart:io';

import 'package:fluvie_server/src/api/ratelimit/client_ip.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Request _request({Map<String, String> headers = const {}, Object? connectionInfo}) => Request(
  'POST',
  Uri.parse('http://localhost/v1/renders'),
  headers: headers,
  context: connectionInfo == null ? const {} : {'shelf.io.connection_info': connectionInfo},
);

void main() {
  group('clientIp', () {
    test('reads the first hop from x-forwarded-for', () {
      final request = _request(
        headers: const {'x-forwarded-for': '203.0.113.5, 10.0.0.1, 10.0.0.2'},
      );
      expect(clientIp(request), '203.0.113.5');
    });

    test('trims whitespace around the first hop', () {
      final request = _request(headers: const {'x-forwarded-for': '  203.0.113.9  '});
      expect(clientIp(request), '203.0.113.9');
    });

    test('falls back to the connection info remote address', () {
      final request = _request(connectionInfo: _FakeConnectionInfo('198.51.100.7'));
      expect(clientIp(request), '198.51.100.7');
    });

    test('prefers x-forwarded-for over the connection info', () {
      final request = _request(
        headers: const {'x-forwarded-for': '203.0.113.5'},
        connectionInfo: _FakeConnectionInfo('198.51.100.7'),
      );
      expect(clientIp(request), '203.0.113.5');
    });

    test('ignores an empty x-forwarded-for and falls back', () {
      final request = _request(
        headers: const {'x-forwarded-for': '   '},
        connectionInfo: _FakeConnectionInfo('198.51.100.7'),
      );
      expect(clientIp(request), '198.51.100.7');
    });

    test('returns a stable unknown sentinel when nothing is available', () {
      expect(clientIp(_request()), 'unknown');
    });
  });
}

/// A minimal [HttpConnectionInfo] exposing just the remote address host.
final class _FakeConnectionInfo implements HttpConnectionInfo {
  _FakeConnectionInfo(String host) : remoteAddress = InternetAddress(host);

  @override
  final InternetAddress remoteAddress;

  @override
  int get localPort => 0;

  @override
  int get remotePort => 0;
}
