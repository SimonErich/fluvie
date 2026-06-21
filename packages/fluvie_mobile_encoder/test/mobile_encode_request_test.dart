import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  MobileEncodeRequest build({
    String framesPath = '/f',
    String outputPath = '/o',
    int width = 64,
    int height = 64,
    int fps = 30,
    int frameCount = 3,
    int bitRate = 1000000,
    MobileVideoCodec codec = MobileVideoCodec.h264,
    List<MobileAudioTrack> audioTracks = const [],
    double audioMasterVolume = 1,
  }) => MobileEncodeRequest(
    framesPath: framesPath,
    outputPath: outputPath,
    width: width,
    height: height,
    fps: fps,
    frameCount: frameCount,
    bitRate: bitRate,
    codec: codec,
    audioTracks: audioTracks,
    audioMasterVolume: audioMasterVolume,
  );

  test('serializes to the channel argument map', () {
    expect(build(codec: MobileVideoCodec.hevc).toArguments(), {
      'framesPath': '/f',
      'outputPath': '/o',
      'width': 64,
      'height': 64,
      'fps': 30,
      'frameCount': 3,
      'bitRate': 1000000,
      'codec': 'hevc',
      'audioMasterVolume': 1.0,
      'audioTracks': <Object?>[],
    });
  });

  test('serializes audio tracks and the master volume', () {
    final request = build(
      audioMasterVolume: 0.9,
      audioTracks: const [MobileAudioTrack(path: '/audio/bed.m4a', volume: 0.5, delayMs: 100)],
    );

    final args = request.toArguments();
    expect(args['audioMasterVolume'], 0.9);
    final tracks = args['audioTracks']! as List;
    expect(tracks, hasLength(1));
    expect((tracks.single as Map)['path'], '/audio/bed.m4a');
    expect((tracks.single as Map)['delayMs'], 100);
  });

  test('rejects an empty frames path', () {
    expect(() => build(framesPath: ''), throwsArgumentError);
  });
  test('rejects an empty output path', () {
    expect(() => build(outputPath: ''), throwsArgumentError);
  });
  test('rejects an odd width', () {
    expect(() => build(width: 65), throwsArgumentError);
  });
  test('rejects a non-positive width', () {
    expect(() => build(width: 0), throwsArgumentError);
  });
  test('rejects an odd height', () {
    expect(() => build(height: 65), throwsArgumentError);
  });
  test('rejects a non-positive fps', () {
    expect(() => build(fps: 0), throwsArgumentError);
  });
  test('rejects a non-positive frame count', () {
    expect(() => build(frameCount: 0), throwsArgumentError);
  });
  test('rejects a non-positive bitrate', () {
    expect(() => build(bitRate: 0), throwsArgumentError);
  });
}
