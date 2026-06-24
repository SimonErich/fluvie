import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/audio/generative_audio.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/audio_mix_resolution.dart';

import '../../rendering/fakes/fake_generative_resolver.dart';

const _music = GenerativeSource.music(providerId: 'suno', prompt: 'lofi');
const _audioFile = AudioSource.file('/cache/m.mp3');

Video _video(List<Widget> children) => Video(
  scenes: [Scene(duration: const Time.frames(30), children: children)],
);

FakeGenerativeResolver _resolver() => FakeGenerativeResolver(audio: {_music: _audioFile});

void main() {
  test('collectAudioTracks folds a generated audio widget into a music track', () {
    final tracks = collectAudioTracks(
      _video(const [GenerativeAudio(source: _music, volume: 0.5)]),
      generative: _resolver(),
    );
    expect(tracks, hasLength(1));
    expect(tracks.single.source, '/cache/m.mp3');
    expect(tracks.single.volume, 0.5);
  });

  test('without a resolver, a GenerativeAudio contributes no track', () {
    final tracks = collectAudioTracks(_video(const [GenerativeAudio(source: _music)]));
    expect(tracks, isEmpty);
  });

  test('collectAudioSources includes the produced generated-audio source', () {
    final sources = collectAudioSources(
      _video(const [GenerativeAudio(source: _music)]),
      generative: _resolver(),
    );
    expect(sources, contains(_audioFile));
  });

  test('resolveAudioMix mixes a generated audio track', () {
    final mix = resolveAudioMix(
      video: _video(const [GenerativeAudio(source: _music)]),
      fps: 30,
      totalFrames: 30,
      generative: _resolver(),
    );
    expect(mix.tracks, hasLength(1));
    expect(mix.tracks.single.source, '/cache/m.mp3');
  });

  test('an asset-backed produced audio source maps to its asset key', () {
    final tracks = collectAudioTracks(
      _video(const [GenerativeAudio(source: _music)]),
      generative: FakeGenerativeResolver(audio: {_music: const AudioSource.asset('beat.mp3')}),
    );
    expect(tracks.single.source, 'beat.mp3');
  });

  test('a network-backed produced audio source maps to its url', () {
    final tracks = collectAudioTracks(
      _video(const [GenerativeAudio(source: _music)]),
      generative: FakeGenerativeResolver(
        audio: {_music: AudioSource.network(Uri.parse('https://cdn.example/beat.mp3'))},
      ),
    );
    expect(tracks.single.source, 'https://cdn.example/beat.mp3');
  });
}
