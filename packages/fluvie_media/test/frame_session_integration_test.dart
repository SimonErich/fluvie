import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluvie_media/native.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['FLUVIE_TEST_NATIVE_MEDIA'] == '1';
  test(
    'cancellation during probing stops and reaps the probe process',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_probe_cancel_');
      final probe = File('${directory.path}/probe.sh');
      final pidFile = File('${directory.path}/probe.pid');
      await probe.writeAsString('#!/bin/sh\necho \$\$ > "${pidFile.path}"\nexec /bin/sleep 30\n');
      await Process.run('chmod', ['+x', probe.path]);
      final cancelled = Completer<void>();
      final tools = FfmpegMediaTools(ffprobePath: probe.path);
      addTearDown(() async {
        await tools.closeAsync();
        await directory.delete(recursive: true);
      });
      final stopped = expectLater(
        tools.probeTimeline('/fixture/source.mp4', whenCancelled: cancelled.future),
        throwsA(isA<MediaCancelledException>()),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!pidFile.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(pidFile.existsSync(), isTrue);
      final pid = int.parse(await pidFile.readAsString());
      cancelled.complete();
      await stopped;
      expect(Process.killPid(pid, ProcessSignal.sigcont), isFalse);
    },
    skip: !enabled || Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'cancellation reaps a blocked decoder before its read completes',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_session_cancel_');
      final encoder = FfmpegMediaTools();
      final source = '${directory.path}/source.mp4';
      final encoded = await encoder.run(encoder.ffmpegPath, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=red:size=16x16:rate=1',
        '-t',
        '1',
        '-c:v',
        'libx264',
        '-y',
        source,
      ]);
      expect(encoded.exitCode, 0);
      final decoder = File('${directory.path}/blocked.sh');
      final pidFile = File('${directory.path}/decoder.pid');
      await decoder.writeAsString('#!/bin/sh\necho \$\$ > "${pidFile.path}"\nexec /bin/sleep 30\n');
      await Process.run('chmod', ['+x', decoder.path]);
      final cancelled = Completer<void>();
      final tools = FfmpegMediaTools(ffmpegPath: decoder.path);
      addTearDown(() async {
        await tools.closeAsync();
        await encoder.closeAsync();
        await directory.delete(recursive: true);
      });
      final session = await tools.openFrameSession(
        Uri.file(source),
        width: 16,
        height: 16,
        whenCancelled: cancelled.future,
      );
      final read = session.readFrames([0]);
      final stopped = expectLater(read, throwsA(isA<MediaCancelledException>()));
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!pidFile.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(pidFile.existsSync(), isTrue);
      final pid = int.parse(await pidFile.readAsString());
      cancelled.complete();
      await stopped;
      await session.close();
      expect(Process.killPid(pid, ProcessSignal.sigcont), isFalse);
    },
    skip: !enabled || Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test(
    'sequential batches reuse one decoder and backward seeks preserve exact pictures',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_session_');
      final tools = FfmpegMediaTools();
      addTearDown(() async {
        await tools.closeAsync();
        await directory.delete(recursive: true);
      });
      final path = '${directory.path}/source.mp4';
      final encoded = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=32x24:rate=30',
        '-t',
        '2',
        '-c:v',
        'libx264',
        '-g',
        '15',
        '-pix_fmt',
        'yuv420p',
        '-y',
        path,
      ]);
      expect(encoded.exitCode, 0, reason: encoded.stderr);
      final reference = await tools.extractFrames(
        Uri.file(path),
        [0, 10, 20, 40],
        width: 32,
        height: 24,
      );
      final session = await tools.openFrameSession(Uri.file(path), width: 32, height: 24);
      for (final index in [0, 10, 20, 40]) {
        final frames = await session.readFrames([index]);
        expect(frames[index]!.rgba, reference[index]!.rgba, reason: 'source frame $index');
      }
      expect(session.decoderStarts, 1);
      final backwards = await session.readFrames([10]);
      expect(backwards[10]!.rgba, reference[10]!.rgba);
      expect(session.decoderStarts, 2);
      await session.close();
      await expectLater(session.readFrames([0]), throwsStateError);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'distant and backward seeks start near an indexed keyframe with B-frame parity',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_indexed_seek_');
      final tools = FfmpegMediaTools();
      addTearDown(() async {
        await tools.closeAsync();
        await directory.delete(recursive: true);
      });
      final source = '${directory.path}/bframes.mp4';
      final encoded = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=32x24:rate=30',
        '-t',
        '8',
        '-c:v',
        'libx264',
        '-g',
        '15',
        '-bf',
        '3',
        '-sc_threshold',
        '0',
        '-pix_fmt',
        'yuv420p',
        source,
      ]);
      expect(encoded.exitCode, 0, reason: encoded.stderr);
      final reference = await tools.extractFrames(
        Uri.file(source),
        [85, 170],
        width: 32,
        height: 24,
      );
      final session = await tools.openFrameSession(Uri.file(source), width: 32, height: 24);
      final distant = await session.readFrames([170]);
      expect(distant[170]!.rgba, reference[170]!.rgba);
      final backwards = await session.readFrames([85]);
      expect(backwards[85]!.rgba, reference[85]!.rgba);
      expect(session.framesRead, lessThan(30));
      expect(session.decoderStarts, 2);
      await session.close();
      final shifted = '${directory.path}/shifted.mp4';
      final remuxed = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-y',
        '-itsoffset',
        '2.5',
        '-i',
        source,
        '-c',
        'copy',
        shifted,
      ]);
      expect(remuxed.exitCode, 0, reason: remuxed.stderr);
      final offset = await tools.openFrameSession(Uri.file(shifted), width: 32, height: 24);
      expect((await offset.readFrames([170]))[170]!.rgba, reference[170]!.rgba);
      expect(offset.framesRead, lessThan(20));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'indexed seeks preserve VFR alpha and container display rotation',
    () async {
      final directory = await Directory.systemTemp.createTemp('fluvie_seek_geometry_');
      final tools = FfmpegMediaTools();
      addTearDown(() async {
        await tools.closeAsync();
        await directory.delete(recursive: true);
      });
      final rgba = Uint8List(100 * 16 * 8 * 4);
      for (var frame = 0; frame < 100; frame++) {
        for (var pixel = 0; pixel < 128; pixel++) {
          rgba.setRange((frame * 128 + pixel) * 4, (frame * 128 + pixel + 1) * 4, [
            frame,
            255 - frame,
            frame * 2 % 256,
            frame * 3 % 256,
          ]);
        }
      }
      final raw = File('${directory.path}/input.rgba')..writeAsBytesSync(rgba);
      final variable = '${directory.path}/variable.mkv';
      final encoded = await tools.run(tools.ffmpegPath, [
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
        '10',
        '-i',
        raw.path,
        '-vf',
        'settb=1/1000,setpts=N*100+floor(N/10)*50',
        '-fps_mode',
        'vfr',
        '-c:v',
        'ffv1',
        '-pix_fmt',
        'bgra',
        variable,
      ]);
      expect(encoded.exitCode, 0, reason: encoded.stderr);
      final session = await tools.openFrameSession(Uri.file(variable), width: 16, height: 8);
      for (final index in [85, 52]) {
        final result = await session.readFrames([index]);
        expect(result[index]!.rgba.sublist(0, 4), [
          index,
          255 - index,
          index * 2 % 256,
          index * 3 % 256,
        ]);
      }
      expect(session.timeline.isVariable, isTrue);
      expect(session.framesRead, lessThan(30));
      await session.close();

      final upright = '${directory.path}/upright.mp4';
      final made = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=16x8:rate=30',
        '-t',
        '2',
        '-c:v',
        'libx264',
        '-g',
        '15',
        '-sc_threshold',
        '0',
        upright,
      ]);
      expect(made.exitCode, 0, reason: made.stderr);
      final rotated = '${directory.path}/rotated.mp4';
      final remuxed = await tools.run(tools.ffmpegPath, [
        '-v',
        'error',
        '-y',
        '-i',
        upright,
        '-c',
        'copy',
        '-metadata:s:v:0',
        'rotate=90',
        rotated,
      ]);
      expect(remuxed.exitCode, 0, reason: remuxed.stderr);
      final reference = await tools.extractFrames(Uri.file(rotated), [50], width: 8, height: 16);
      final rotation = await tools.openFrameSession(Uri.file(rotated), width: 8, height: 16);
      expect((await rotation.readFrames([50]))[50]!.rgba, reference[50]!.rgba);
      expect(rotation.framesRead, lessThan(20));
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
