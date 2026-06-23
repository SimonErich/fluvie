import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/audio_graph_nodes.dart';
import 'package:fluvie/src/rendering/encoding/export_args.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_filter_graph.dart';

part 'ffmpeg_args_export.dart';

/// Builds the complete FFmpeg encode invocation as a typed **argument
/// array** — never a shell string, never concatenated paths.
///
/// Every file name is validated to be a bare, sandbox-relative name (no
/// separators, no leading `-`), so an argument can never escape the render
/// sandbox or be parsed as a flag. [build] always injects the determinism
/// quartet `-fflags +bitexact -flags:v +bitexact -map_metadata -1` plus
/// `-threads 1`, which is what makes a double encode byte-identical, and it
/// never emits `-y`: output files are always fresh inside the sandbox.
///
/// The MP4 output is [setH264Output]; the non-MP4 export modes (GIF,
/// image sequence, transparent WebM) and the poster still are the
/// `setGifOutput`/`setImageSequenceOutput`/`setTransparentOutput`/
/// `setPosterOutput` setters in the `ffmpeg_args_export.dart` part. Exactly
/// one output setter may be called per builder.
final class FfmpegArgsBuilder {
  final List<List<String>> _inputs = [];
  List<String> _outputOptions = const [];
  List<FfmpegAudioNode> _audio = const [];
  FfmpegAudioMix? _amix;
  String? _outputName;

  /// The pad label the audio mix output binds to in the `-filter_complex` graph.
  static const String _mixOutLabel = 'aout';

  /// Declares a raw RGBA8888 frame-stream input read from the
  /// sandbox-relative file [name], sized [width]x[height] at [fps].
  void addRawVideoInput({
    required String name,
    required int width,
    required int height,
    required int fps,
  }) {
    validateFfmpegName(name, 'name');
    _inputs.add([
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-video_size',
      '${width}x$height',
      '-framerate',
      '$fps',
      '-i',
      name,
    ]);
  }

  /// Declares a PNG image-sequence frame-stream input read from the
  /// sandbox-relative `image2` [pattern] (one `%0Nd` token, e.g.
  /// `frame_%06d.png`) at [fps], starting at frame index 0.
  ///
  /// Unlike [addRawVideoInput] no size or pixel format is set: each PNG carries
  /// its own dimensions and format. This is the browser encoder's bounded-memory
  /// input — one small PNG per frame instead of a single multi-gigabyte raw
  /// buffer — and the web encoder expands the pattern to the actual frame files.
  void addImageSequenceInput({required String pattern, required int fps}) {
    validateFfmpegName(pattern, 'pattern', allowImagePattern: true);
    _inputs.add(['-framerate', '$fps', '-start_number', '0', '-i', pattern]);
  }

  /// Declares a `lavfi` generated input described by [graph]
  /// (for example `testsrc=duration=1`). The graph must be non-empty and not
  /// start with `-`, so it can never be parsed as a flag.
  void addLavfiInput(String graph) {
    if (graph.isEmpty || graph.startsWith('-')) {
      throw ArgumentError.value(graph, 'graph', 'must be a non-empty lavfi graph, not a flag');
    }
    _inputs.add(['-f', 'lavfi', '-i', graph]);
  }

  /// Declares the single H.264/MP4 output written to the sandbox-relative
  /// file [name] at [fps], with [quality] mapped to a CRF level.
  ///
  /// A non-empty [filters] graph is emitted as `-vf`. When [audio] nodes are
  /// present their inputs are appended after the video inputs and mapped
  /// video-then-audio with `-shortest`; with no audio the output is `-an`.
  /// Nodes that contribute a `filterChain` are routed through `-filter_complex`
  /// and combined by [amix] into one AAC audio stream. May be
  /// called once; a second call throws [StateError].
  void setH264Output({
    required String name,
    required Quality quality,
    required int fps,
    FfmpegFilterGraph? filters,
    List<FfmpegAudioNode> audio = const [],
    FfmpegAudioMix? amix,
  }) {
    _beginOutput(name);
    _audio = List.unmodifiable(audio);
    _amix = amix;
    _outputOptions = [
      if (filters != null && !filters.isEmpty) ...['-vf', filters.serialize()],
      '-c:v',
      'libx264',
      '-preset',
      'medium',
      '-crf',
      '${_crfFor(quality)}',
      '-pix_fmt',
      'yuv420p',
      '-r',
      '$fps',
    ];
  }

  /// The full argument array: inputs (video first, then audio nodes), output
  /// options, stream mapping, the bitexact determinism quartet, and the
  /// output name last. Pure — repeated calls return an equal array.
  ///
  /// Throws [StateError] when no input was added or no output was set.
  List<String> build() {
    final outputName = _outputName;
    if (outputName == null) throw StateError('setH264Output must be called before build()');
    if (_inputs.isEmpty) throw StateError('at least one input must be added before build()');
    final videoInputCount = _inputs.length;
    return [
      for (final input in _inputs) ...input,
      for (final node in _audio) ...node.inputArgs(),
      ..._outputOptions,
      ..._audioMapping(videoInputCount),
      '-fflags',
      '+bitexact',
      '-flags:v',
      '+bitexact',
      '-map_metadata',
      '-1',
      '-threads',
      '1',
      outputName,
    ];
  }

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
        '-shortest',
      ];
    }
    final mix = _amix;
    if (mix == null) {
      throw StateError('audio track nodes need an FfmpegAudioMix; pass amix: to setH264Output.');
    }
    final graph = [...chains, mix.mixChain(labels: padLabels, outLabel: _mixOutLabel)].join(';');
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

  /// CRF per quality level — private policy of this builder.
  static int _crfFor(Quality quality) => switch (quality) {
    Quality.low => 28,
    Quality.medium => 23,
    Quality.high => 18,
    Quality.max => 14,
  };

  /// Records the validated output [name], guarding against a second output
  /// setter (every mode is one-shot). [allowImagePattern] permits exactly one
  /// `%0Nd` token for the `image2` muxer; the shared [validateFfmpegName]
  /// boundary rejects every traversal/flag/format-token injection.
  void _beginOutput(String name, {bool allowImagePattern = false}) {
    if (_outputName != null) {
      throw StateError('an output setter was already called (output: $_outputName)');
    }
    validateFfmpegName(name, 'name', allowImagePattern: allowImagePattern);
    _outputName = name;
  }
}
