@Tags(['ffmpeg'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('single-frame native extraction does not fetch an unstaged network source', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      await server.close(force: true);
    });
    var requests = 0;
    server.listen((request) {
      requests++;
      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close());
    });

    await expectLater(
      container
          .read(frameExtractionServiceProvider)
          .extractFrame(
            Uri.http('127.0.0.1:${server.port}', '/unstaged.mp4'),
            0,
            width: 1,
            height: 1,
          ),
      throwsA(isA<FluvieEncodeException>()),
    );
    expect(requests, 0, reason: 'Network media must be staged by the allowlisted loader.');
  }, timeout: const Timeout(Duration(seconds: 15)));
}
