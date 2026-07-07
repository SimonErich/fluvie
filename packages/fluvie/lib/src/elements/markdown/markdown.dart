import 'package:flutter/widgets.dart'
    show
        Align,
        Alignment,
        BuildContext,
        Column,
        CrossAxisAlignment,
        Offset,
        Opacity,
        StatelessWidget,
        Transform,
        Widget;
import 'package:fluvie/src/animation/stagger/stagger_offsets.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/markdown/parse/markdown_parser.dart';
import 'package:fluvie/src/elements/markdown/render/ast_renderer.dart';
import 'package:fluvie/src/elements/markdown/render/markdown_style.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart' show visibleForTesting;

/// Renders Markdown as a frame-driven element — an intrinsic widget whose
/// constructor takes content behaviour only.
///
/// The [source] is parsed **once** per content (cached by content hash) and
/// rendered to widgets by an `AstRenderer`: headings, paragraphs, lists,
/// blockquotes, inline `code` / **bold** / *italic*, fenced code, and images. A
/// fenced code block delegates to a `Code` widget (highlighted in its fence
/// language) and an image delegates to an `Image` widget. Any unsupported node
/// renders as plain text.
///
/// ```dart
/// Markdown(
///   '# Release notes\n\n- Faster renders\n- `Code` highlighting',
///   reveal: 1.seconds,
/// );
/// ```
///
/// With [reveal] non-null the top-level blocks appear one after another over the
/// element window (`staggerOffsetFrames` over the block count), each fading and
/// sliding up as its turn arrives; `null` shows the whole document at once.
/// Colors follow [style] or `context.fluvie`. Transforms and effects ride
/// `.animate()`; [shared] wraps the result in a `SharedElement` for a hero morph
/// across a scene boundary.
///
/// Two durations can meet here: [reveal] times the intrinsic content
/// reveal, while transforms and opacity ride `.animate()` with their own
/// timing.
final class Markdown extends StatelessWidget implements CollectibleChildren {
  /// Renders [source] in [style] (or `context.fluvie`), optionally revealed
  /// block by block over [reveal].
  const Markdown(this.source, {this.style, this.reveal, this.shared, super.key});

  /// The Markdown document this element parses and renders.
  final String source;

  /// The text styles to render with, or `null` to read `context.fluvie`.
  final MarkdownStyle? style;

  /// How long the block-by-block reveal runs, or `null` to show everything at
  /// once; resolved against the element window so a relative time scales with
  /// the scene.
  final Time? reveal;

  /// An optional hero anchor: when non-null the rendered Markdown morphs across
  /// the boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  /// The blocks [nodes] render to under this element's style; the per-block
  /// reveal wraps these. Exposed for tests to count the rendered blocks without
  /// mounting the frame clock.
  @visibleForTesting
  List<Widget> blocksFor(List<md.Node> nodes, {MarkdownStyle? style}) =>
      AstRenderer(style: style ?? const MarkdownStyle.fallback()).render(nodes);

  /// The inline images the document renders, as bare [Image] widgets, so the
  /// collect pass pre-resolves each one before the frame loop.
  ///
  /// The `AstRenderer` mounts every image inside a `WidgetSpan`, which the
  /// structural walk cannot see into (a `StatelessWidget`'s built spans are
  /// invisible to it), so without this a document with an image would throw at
  /// paint in capture (its source never pre-resolved). Each carrier mirrors
  /// `_imageSpan`'s `Image.network(src)` exactly, so it shares the content hash
  /// the painted image looks up.
  @override
  Iterable<Widget> get collectibleChildren sync* {
    for (final src in _imageSources(parseMarkdownCached(source))) {
      yield Image.network(src);
    }
  }

  /// Every `img` node's `src` in the document, in reading order (recursing into
  /// nested inline containers), mirroring `AstRenderer._imageSpan`'s fallback.
  static Iterable<String> _imageSources(List<md.Node> nodes) sync* {
    for (final node in nodes) {
      if (node is! md.Element) continue;
      if (node.tag == 'img') yield node.attributes['src'] ?? '';
      final children = node.children;
      if (children != null) yield* _imageSources(children);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = FrameProvider.of(context).frame;
    final scope = TimeScopeProvider.of(context);
    final resolvedStyle = style ?? MarkdownStyle.fromTokens(context.fluvie);
    final blocks = blocksFor(parseMarkdownCached(source), style: resolvedStyle);
    final revealed = reveal == null ? blocks : _revealBlocks(blocks, frame, scope);
    final visible = Align(
      alignment: Alignment.topLeft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: revealed),
    );
    return wrapShared(shared, visible);
  }

  /// The visible subset of [blocks] at [frame], each block appearing once its
  /// stagger offset passes and fading / sliding up across the per-block window.
  ///
  /// Blocks are spread evenly across the [reveal] window via
  /// [staggerOffsetFrames] (over the block count), and a block is rendered once
  /// its offset has passed (so block 0 shows from frame 0). The per-block fade
  /// runs over one even slice of the window.
  List<Widget> _revealBlocks(List<Widget> blocks, int frame, TimeScopeData scope) {
    if (blocks.isEmpty) return const [];
    final windowFrames = reveal!.resolveFrames(scope);
    final elapsed = frame - scope.startFrame;
    final offsets = staggerOffsetFrames(
      stagger: Stagger.evenly(over: reveal!),
      childCount: blocks.length,
      scope: scope,
    );
    final perBlock = (windowFrames / blocks.length).ceil().clamp(1, windowFrames + 1);
    final progress = staggeredRevealProgress(
      elapsed: elapsed,
      offsets: offsets,
      perSegmentFrames: perBlock,
    );
    return [
      for (var i = 0; i < blocks.length; i++)
        if (elapsed >= offsets[i]) _revealed(blocks[i], progress[i]),
    ];
  }

  /// One block faded to [progress] and lifted from a small upward offset.
  Widget _revealed(Widget block, double progress) => Opacity(
    opacity: progress,
    child: Transform.translate(offset: Offset(0, (1 - progress) * 12), child: block),
  );
}
