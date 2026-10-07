import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/local_media_bridge.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_media/native.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test(
    'native alpha video uploads, probes and decodes through the browser protocol',
    () async {
      final project = await Directory.systemTemp.createTemp('fluvie_bridge_codec_');
      addTearDown(() => project.delete(recursive: true));
      final toolchain = await ensureFfmpegToolchain(const IoProcessRunner(), mode: 'system');
      final tools = FfmpegMediaTools(
        ffmpegPath: toolchain.ffmpegPath,
        ffprobePath: toolchain.ffprobePath,
      );
      addTearDown(tools.close);
      final pixels = Uint8List.fromList(
        List.generate(3 * 16 * 8, (_) => [100, 50, 25, 128]).expand((pixel) => pixel).toList(),
      );
      final raw = File('${project.path}/rgba');
      await raw.writeAsBytes(pixels);
      final video = File('${project.path}/alpha.mkv');
      final encoded = await tools.run(toolchain.ffmpegPath, [
        '-v',
        'error',
        '-y',
        '-f',
        'rawvideo',
        '-pixel_format',
        'rgba',
        '-video_size',
        '16x8',
        '-framerate',
        '1',
        '-i',
        raw.path,
        '-c:v',
        'ffv1',
        '-pix_fmt',
        'bgra',
        video.path,
      ]);
      expect(encoded.exitCode, 0, reason: encoded.stderr);
      final bridge = await LocalMediaBridge.start(toolchain: toolchain, projectDir: project);
      addTearDown(bridge.close);
      final headers = {'X-Fluvie-Token': bridge.sessionToken};
      final upload = await http.post(
        bridge.endpoint.resolve('/sources'),
        headers: headers,
        body: await video.readAsBytes(),
      );
      expect(upload.statusCode, 200, reason: upload.body);
      final metadata = jsonDecode(upload.body) as Map<String, Object?>;
      expect(metadata['hasAlpha'], isTrue);
      expect(metadata['frameCount'], 3);
      final timeline = MediaTimeline.fromJson(metadata['timeline']! as Map<String, Object?>);
      expect(timeline.frameAt(1.5), 1);
      final decoded = await http.post(
        bridge.endpoint.resolve('/sources/${metadata['id']}/frames'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'indices': [0],
          'width': 16,
          'height': 8,
        }),
      );
      expect(decoded.statusCode, 200);
      expect(decoded.bodyBytes, pixels.sublist(0, 16 * 8 * 4));
      for (final index in [1, 2]) {
        final frame = await http.post(
          bridge.endpoint.resolve('/sources/${metadata['id']}/frames'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'indices': [index],
            'width': 16,
            'height': 8,
          }),
        );
        expect(frame.statusCode, 200, reason: frame.body);
        expect(frame.bodyBytes, decoded.bodyBytes);
      }
      final status = await http.get(bridge.endpoint.resolve('/status'), headers: headers);
      expect(jsonDecode(status.body), containsPair('decoderStarts', 1));
    },
    skip: Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
