part of 'ffmpeg_args.dart';

extension _FfmpegAudioMapping on FfmpegArgsBuilder {
  /// The pad label the audio mix output binds to in the `-filter_complex` graph.
  static const String _mixOutLabel = 'aout';

  /// The audio mapping tail: `-an` with no audio, a `-filter_complex` amix graph
  /// when nodes contribute filter chains, or the legacy direct
  /// `-map N:a` path for chain-less fixture nodes. [videoInputCount] is the
  /// FFmpeg input index the first audio node was assigned.
  List<String> _audioMapping(int videoInputCount) {
    if (_audio.isEmpty) return const ['-an'];
    final chains = <String>[];
    final padLabels = <String>[];
    for (var i = 0; i < _audio.length; i++) {
      final label = 'a$i';
      final chain = _audio[i].filterChain(inputIndex: videoInputCount + i, label: label);
      if (chain == null) continue;
      chains.add(chain);
      padLabels.add(label);
    }
    if (chains.isEmpty) {
      return [
        '-map',
        '0:v:0',
        for (var i = 0; i < _audio.length; i++) ...[
          '-map',
          _audio[i].mapSpecifier(videoInputCount + i),
        ],
        '-af',
        if (_audioStartSeconds > 0)
          'apad,atrim=start=$_audioStartSeconds,asetpts=PTS-STARTPTS'
        else
          'apad',
        '-shortest',
      ];
    }
    final mix = _amix;
    if (mix == null) {
      throw StateError('audio track nodes need an FfmpegAudioMix; pass amix: to setH264Output.');
    }
    final graph = [
      ...chains,
      mix.mixChain(labels: padLabels, outLabel: 'mixed'),
      '[mixed]apad${_audioStartSeconds > 0 ? ',atrim=start=$_audioStartSeconds,asetpts=PTS-STARTPTS' : ''}[$_mixOutLabel]',
    ].join(';');
    return [
      '-filter_complex',
      graph,
      '-map',
      '0:v:0',
      '-map',
      '[$_mixOutLabel]',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-shortest',
    ];
  }
}
