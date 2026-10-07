import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_cli/fluvie_cli.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

final class _LoopbackClient extends http.BaseClient {
  _LoopbackClient(this.endpoint);
  final Uri endpoint;
  final http.Client _inner = http.Client();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(http.Request(request.method, endpoint));

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

void main() {
  group('HttpFfmpegDownloader', () {
    test('returns the body bytes of a 200 response', () async {
      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final client = MockClient((_) async => http.Response.bytes(payload, 200));

      final bytes = await HttpFfmpegDownloader(client).download(
        'https://github.com/BtbN/FFmpeg-Builds/releases/download/x/ffmpeg.tar.xz',
      );

      expect(bytes, equals(payload));
    });

    test('rejects a non-allowlisted host before any request', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });

      await expectLater(
        () => HttpFfmpegDownloader(client).download('https://evil.example.com/ffmpeg.zip'),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('allowlist'))),
      );
      expect(called, isFalse);
    });

    test('rejects a non-HTTPS URL', () async {
      final client = MockClient((_) async => http.Response('', 200));
      await expectLater(
        () => HttpFfmpegDownloader(client).download('http://github.com/x.zip'),
        throwsA(isA<CliFailure>()),
      );
    });

    test('maps a non-200 status to a CliFailure naming the code', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      await expectLater(
        () => HttpFfmpegDownloader(client).download('https://evermeet.cx/ffmpeg/ffmpeg.zip'),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('404'))),
      );
    });

    test('maps a transport error to a CliFailure', () async {
      final client = MockClient((_) async => throw http.ClientException('boom'));
      await expectLater(
        () => HttpFfmpegDownloader(client).download('https://www.osxexperts.net/ffmpeg.zip'),
        throwsA(isA<CliFailure>().having((e) => e.message, 'message', contains('download'))),
      );
    });

    test('rejects a declared oversized body before consuming it', () async {
      final cancelled = Completer<void>();
      final body = StreamController<List<int>>(onCancel: cancelled.complete);
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(body.stream, 200, contentLength: 9),
      );
      await expectLater(
        HttpFfmpegDownloader(client).downloadBounded('https://github.com/archive.zip', maxBytes: 8),
        throwsA(isA<CliFailure>().having((error) => error.message, 'limit', contains('8 bytes'))),
      );
      await cancelled.future.timeout(const Duration(seconds: 2));
      await body.close();
    });

    test('direct callers are bounded by the default archive size', () async {
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          const Stream.empty(),
          200,
          contentLength: HttpFfmpegDownloader.maxArchiveBytes + 1,
        ),
      );
      await expectLater(
        HttpFfmpegDownloader(client).download('https://github.com/archive.zip'),
        throwsA(
          isA<CliFailure>().having((error) => error.code, 'code', 'toolchain_archive_too_large'),
        ),
      );
    });

    test('accepts an exact-size chunked body and rejects nonpositive bounds', () async {
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([
            [1, 2],
            [3, 4],
          ]),
          200,
        ),
      );
      final downloader = HttpFfmpegDownloader(client);
      expect(
        await downloader.downloadBounded('https://github.com/archive.zip', maxBytes: 4),
        [1, 2, 3, 4],
      );
      for (final size in [0, -1]) {
        await expectLater(
          downloader.downloadBounded('https://github.com/archive.zip', maxBytes: size),
          throwsArgumentError,
        );
      }
    });

    test('stops an oversized real chunked response without waiting for EOF', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final release = Completer<void>();
      var completedBody = false;
      final serving = server.first.then((request) async {
        request.response.bufferOutput = false;
        request.response.add(List<int>.filled(9, 1));
        await request.response.flush();
        await release.future;
        completedBody = true;
        await request.response.close();
      });
      final client = _LoopbackClient(Uri.parse('http://127.0.0.1:${server.port}/archive'));
      try {
        await expectLater(
          HttpFfmpegDownloader(client)
              .downloadBounded('https://github.com/archive.zip', maxBytes: 8)
              .timeout(const Duration(seconds: 2)),
          throwsA(isA<CliFailure>().having((error) => error.message, 'limit', contains('8 bytes'))),
        );
        expect(completedBody, isFalse);
        expect(client.closed, isFalse, reason: 'The injected client belongs to its caller.');
      } finally {
        release.complete();
        client.close();
        await server.close(force: true);
        await serving;
      }
    });
  });
}
