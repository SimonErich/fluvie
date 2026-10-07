import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show FluvieRenderException;
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uploads once and returns exact sorted native frames', () async {
    var uploads = 0;
    final decoder = LocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        expect(request.headers['X-Fluvie-Token'], 'session');
        if (request.url.path == '/sources') {
          uploads++;
          return http.Response(
            jsonEncode({
              'id': 'clip',
              'fps': 30.0,
              'frameCount': 10,
              'width': 2,
              'height': 1,
              'hasAudio': true,
              'timeline': {
                'schemaVersion': 1,
                'presentationTimesUs': [0, 100000, 400000],
                'durationUs': 1000000,
              },
            }),
            200,
          );
        }
        expect(jsonDecode(request.body), {
          'indices': [0, 5],
          'width': 2,
          'height': 1,
        });
        return http.Response.bytes([...List.filled(8, 10), ...List.filled(8, 20)], 200);
      }),
    );
    addTearDown(decoder.dispose);
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect((await decoder.probe(bytes)).hasAudio, isTrue);
    expect((await decoder.probeTimeline(bytes))?.frameAt(.35), 1);
    final frames = await decoder.extractFrames(bytes, [5, 0, 5], width: 2, height: 1);
    expect(uploads, 1);
    expect(frames[0]!.rgba, List.filled(8, 10));
    expect(frames[5]!.rgba, List.filled(8, 20));
  });

  test('invalid frame dimensions are rejected before uploading a source', () async {
    final requests = <Uri>[];
    final decoder = LocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response('{"id":"clip"}', 200);
      }),
    );
    addTearDown(decoder.dispose);

    await expectLater(
      decoder.extractFrames(Uint8List.fromList([1, 2, 3]), [0], width: 0, height: 1),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });

  test('empty frame requests need no upload but still respect disposal', () async {
    final requests = <Uri>[];
    final decoder = LocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response('{"id":"clip"}', 200);
      }),
    );
    addTearDown(decoder.dispose);
    final bytes = Uint8List.fromList([1, 2, 3]);

    expect(await decoder.extractFrames(bytes, [], width: 1, height: 1), isEmpty);
    expect(requests, isEmpty);
    decoder.dispose();
    await expectLater(decoder.extractFrames(bytes, [], width: 1, height: 1), throwsStateError);
  });

  test('disposal stops all callers sharing an in-flight source upload', () async {
    final started = Completer<void>();
    final upload = Completer<http.Response>();
    final requests = <String>[];
    final decoder = LocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/sources') {
          started.complete();
          return upload.future;
        }
        return http.Response.bytes([1, 2, 3, 255], 200);
      }),
    );
    addTearDown(decoder.dispose);
    final bytes = Uint8List.fromList([1, 2, 3]);
    final first = decoder.extractFrames(bytes, [0], width: 1, height: 1);
    final second = decoder.extractFrames(bytes, [0], width: 1, height: 1);
    final stopped = Future.wait([
      expectLater(first, throwsStateError),
      expectLater(second, throwsStateError),
    ]);

    await started.future;
    decoder.dispose();
    upload.complete(http.Response('{"id":"clip"}', 200));
    await stopped;
    expect(requests, ['/sources']);
  });

  test('disposed decoders do not publish pixels from an in-flight frame response', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final decoder = LocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient((request) async {
        if (request.url.path == '/sources') return http.Response('{"id":"clip"}', 200);
        started.complete();
        return response.future;
      }),
    );
    addTearDown(decoder.dispose);
    final stopped = expectLater(
      decoder.extractFrames(Uint8List.fromList([1, 2, 3]), [0], width: 1, height: 1),
      throwsStateError,
    );

    await started.future;
    decoder.dispose();
    response.complete(http.Response.bytes([1, 2, 3, 255], 200));
    await stopped;
  });

  test('the decoder factory exposes disposal and failed source uploads can be retried', () async {
    final responses = [
      http.Response('Source temporarily unavailable', 503),
      http.Response(
        '{"id":"clip","fps":2,"frameCount":4,"width":2,"height":1,"hasAudio":false}',
        200,
      ),
    ];
    final decoder = createLocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient((_) async => responses.removeAt(0)),
    );
    addTearDown(decoder.dispose);
    final bytes = Uint8List.fromList([1, 2, 3]);

    await expectLater(
      decoder.probe(bytes),
      throwsA(
        isA<FluvieRenderException>().having(
          (error) => error.message,
          'source failure',
          contains('(503): Source temporarily unavailable'),
        ),
      ),
    );
    expect(await decoder.probe(bytes), (
      fps: 2.0,
      frameCount: 4,
      width: 2,
      height: 1,
      hasAudio: false,
    ));
    expect(await decoder.probeTimeline(bytes), isNull);
    decoder.dispose();
    await expectLater(decoder.probe(bytes), throwsStateError);
  });

  test('truncated native frame payloads fail without inventing missing pixels', () async {
    final decoder = LocalFfmpegClipDecoder(
      endpoint: Uri.parse('http://127.0.0.1:1234'),
      sessionToken: 'session',
      httpClient: MockClient(
        (request) async => request.url.path == '/sources'
            ? http.Response('{"id":"clip"}', 200)
            : http.Response.bytes([1, 2, 3], 200),
      ),
    );
    addTearDown(decoder.dispose);

    await expectLater(
      decoder.extractFrames(Uint8List.fromList([1, 2, 3]), [0], width: 1, height: 1),
      throwsA(
        isA<FluvieRenderException>().having(
          (error) => error.message,
          'missing pixels',
          'Native preview returned 3 bytes; expected 4.',
        ),
      ),
    );
  });
}
