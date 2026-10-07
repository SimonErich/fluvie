import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/encoding/audio_track_node.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/video_mode/video_audio_structure.dart';

void main() {
  test(
    'razoring trimmed, placed, faded and automated music preserves audible PCM',
    () async {
      final document = EditorDocument.fromJson(const {
        'fluvieSpec': 1,
        'fps': 20,
        'size': {'width': 100, 'height': 100},
        'scenes': [
          {'duration': '5s'},
        ],
        'audio': [
          {
            'kind': 'music',
            'source': {'kind': 'asset', 'value': 'source.wav'},
            'at': {'kind': 'at', 'time': '0.5s'},
            'trim': {'from': '0.4s', 'to': '3.4s'},
            'fadeIn': '0.8s',
            'fadeOut': '0.8s',
            'automation': {
              'volume': {
                'values': [0.2, 1, 0.3, 0.8],
                'positions': ['0r', '0.3r', '0.6r', '1r'],
              },
            },
          },
        ],
      });
      final model = VideoLaneModel.build(document: document);
      final edit = audioBarRazored(model, 'audio:v:0', 45, document: document)!;
      expect(edit.note, isNull);
      final history = DocumentHistory(document)..dispatch(edit.command!);
      addTearDown(history.dispose);
      final split = history.document;
      expect(split.spec.audio, hasLength(2));
      List<ResolvedAudioTrack> tracks(EditorDocument doc) => [
        for (final view in audioTrackViews(doc, VideoTimebase.of(doc))) view.resolved,
      ];

      const rate = 48000;
      final source = (
        sampleRate: rate,
        samples: Float64List.fromList([
          for (var i = 0; i < rate * 4; i++)
            0.08 * math.sin(i * 2 * math.pi * 437 / rate) +
                0.04 * math.sin(i * 2 * math.pi * 733 / rate),
        ]),
      );
      Uint8List preview(EditorDocument doc) => renderAudioPreviewWav(
        tracks: [for (final track in tracks(doc)) AudioPreviewTrack(audio: source, track: track)],
        startSeconds: 0,
        durationSeconds: 5,
      );
      final before = readPcmWav(preview(document)).samples;
      final after = readPcmWav(preview(split)).samples;
      var maxDelta = 0.0;
      for (var i = 0; i < before.length; i++) {
        maxDelta = math.max(maxDelta, (before[i] - after[i]).abs());
      }
      expect(
        maxDelta,
        lessThan(0.0002),
        reason: 'Preview source phase and gain must survive the cut',
      );

      final directory = await Directory.systemTemp.createTemp('fluvie_audio_cut_');
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/source.wav').writeAsBytes(
        renderAudioPreviewWav(
          tracks: [
            AudioPreviewTrack(
              audio: source,
              track: const ResolvedAudioTrack(source: 'a'),
            ),
          ],
          startSeconds: 0,
          durationSeconds: 4,
        ),
      );
      Future<Float64List> encode(EditorDocument doc, String output) async {
        final nodes = [
          for (final track in tracks(doc)) AudioTrackNode.fromResolved(track, name: 'source.wav'),
        ];
        final labels = [for (var i = 0; i < nodes.length; i++) '[a$i]'].join();
        final graph = [
          for (var i = 0; i < nodes.length; i++) nodes[i].filterChain(inputIndex: i, label: 'a$i'),
          '${labels}amix=inputs=${nodes.length}:normalize=0,apad,atrim=end=5[out]',
        ].join(';');
        final result = await Process.run('ffmpeg', [
          '-y',
          '-nostdin',
          '-threads',
          '1',
          '-filter_complex_threads',
          '1',
          '-v',
          'error',
          for (final node in nodes) ...node.inputArgs(),
          '-filter_complex',
          graph,
          '-map',
          '[out]',
          '-ar',
          '$rate',
          '-ac',
          '1',
          '-f',
          'f32le',
          output,
        ], workingDirectory: directory.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final data = ByteData.sublistView(await File('${directory.path}/$output').readAsBytes());
        return Float64List.fromList([
          for (var i = 0; i < data.lengthInBytes; i += 4) data.getFloat32(i, Endian.little),
        ]);
      }

      final originalPcm = await encode(document, 'original.pcm');
      final splitPcm = await encode(split, 'split.pcm');
      expect(originalPcm.length, rate * 5);
      expect(splitPcm.length, originalPcm.length);
      var previewError = 0.0;
      var squaredError = 0.0;
      for (var i = 0; i < originalPcm.length; i++) {
        squaredError += math.pow(originalPcm[i] - splitPcm[i], 2);
        previewError += math.pow(originalPcm[i] - before[i], 2);
      }
      expect(
        math.sqrt(squaredError / originalPcm.length),
        lessThan(0.001),
        reason:
            'Real FFmpeg must preserve the source phase, delay, fades and envelope across razor',
      );
      expect(
        math.sqrt(previewError / originalPcm.length),
        // FFmpeg evaluates volume once per decoded audio packet; the pure
        // audition mixer evaluates per sample. WAV packets here hold 2048
        // samples, so this bound allows that known gain-control quantization.
        lessThan(0.0015),
        reason: 'Export must retain leading silence and match the absolute preview clock',
      );
      history.undo();
      expect(history.document.renderDigest, document.renderDigest);
      history.redo();
      expect(history.document.renderDigest, split.renderDigest);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
