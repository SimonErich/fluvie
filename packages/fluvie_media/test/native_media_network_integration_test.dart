import 'dart:io';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  test(
    'probing a local DASH manifest cannot fetch remote segments',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_media_network_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      final subscription = server.listen((request) async {
        requests.add(request.uri.path);
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
      final tools = FfmpegMediaTools(
        timeout: const Duration(seconds: 5),
        runner: (executable, arguments, {workingDirectory}) async {
          final result = await Process.run(
            executable,
            arguments,
            workingDirectory: workingDirectory,
          );
          return (
            exitCode: result.exitCode,
            stdout: result.stdout as String,
            stderr: result.stderr as String,
          );
        },
      );
      addTearDown(() async {
        await tools.closeAsync();
        await server.close(force: true);
        await subscription.cancel();
        await directory.delete(recursive: true);
      });
      final origin = 'http://127.0.0.1:${server.port}';
      final manifest = File('${directory.path}/clip.mpd');
      await manifest.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static"
    mediaPresentationDuration="PT1S" minBufferTime="PT1S"
    profiles="urn:mpeg:dash:profile:isoff-main:2011">
  <Period duration="PT1S">
    <AdaptationSet mimeType="video/mp4" contentType="video">
      <Representation id="video" bandwidth="1000" codecs="avc1.42c01e" width="16" height="16">
        <SegmentList timescale="1" duration="1">
          <Initialization sourceURL="$origin/init.mp4"/>
          <SegmentURL media="$origin/segment.m4s"/>
        </SegmentList>
      </Representation>
    </AdaptationSet>
  </Period>
</MPD>
''');

      final control = await tools.run(tools.ffprobePath, [
        '-v',
        'error',
        '-protocol_whitelist',
        'file,http,tcp',
        '-show_format',
        manifest.path,
      ]);
      expect(control.exitCode, isNot(0));
      expect(requests, contains('/init.mp4'), reason: 'The canary must detect permitted fetches.');
      requests.clear();

      await expectLater(tools.probeReport(manifest.path), throwsA(isA<MediaProcessException>()));
      expect(requests, isEmpty, reason: 'Native media must not bypass the network allowlist.');
    },
    skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1',
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
