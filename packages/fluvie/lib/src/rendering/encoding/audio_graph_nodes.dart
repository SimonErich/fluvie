/// One audio input lane in an encode plan: its FFmpeg input arguments and the
/// `-map` specifier that routes it into the output.
///
/// This is the encoder's audio contract: the argument
/// builder accepts a list of nodes and emits their inputs, maps and
/// `-shortest` without knowing what produces the sound. A silent test fixture
/// exercises the non-empty path; the real mix nodes (the audio layer's track +
/// amix) route through the optional [filterChain]/[FfmpegAudioMix] members
/// below.
///
/// A node that returns `null` from [filterChain] is mapped directly by its
/// [mapSpecifier] (the legacy lavfi-style fixture path); a node that returns a
/// chain is routed through `-filter_complex` and mapped from the mix's output
/// pad instead.
abstract interface class FfmpegAudioNode {
  /// The argument-array fragment that declares this node's input, ending with
  /// `-i <source>` (for example a `lavfi` source or a pre-resolved file).
  List<String> inputArgs();

  /// The `-map` value selecting this node's audio stream, given the
  /// [inputIndex] FFmpeg assigned to its input (for example `1:a`).
  String mapSpecifier(int inputIndex);

  /// The `-filter_complex` chain this node contributes, reading FFmpeg input
  /// [inputIndex]'s audio and producing the named [label] pad — or `null` to be
  /// mapped directly by [mapSpecifier] with no filtering.
  String? filterChain({required int inputIndex, required String label});
}

/// The mixdown stage of a `-filter_complex` audio graph:
/// combines every per-track pad into one output pad.
///
/// The argument builder hands it the ordered pad labels its [FfmpegAudioNode]s
/// produced and the single output label to bind, and emits the returned chain
/// after the per-track chains. Kept abstract here so the builder stays in
/// `rendering` while the real `AmixNode` lives in the `audio` layer.
// One member by design: the contract is the *type* injected into the arg builder.
// ignore: one_member_abstracts
abstract interface class FfmpegAudioMix {
  /// The chain reading every pad in [labels] and producing the [outLabel] pad.
  String mixChain({required List<String> labels, required String outLabel});
}
