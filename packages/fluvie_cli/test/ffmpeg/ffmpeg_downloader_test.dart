import 'dart:typed_data';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

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
  });
}
