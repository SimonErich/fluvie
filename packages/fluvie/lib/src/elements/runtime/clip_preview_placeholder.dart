part of 'clip_painter.dart';

/// The live-preview stand-in for a [ClipPainter]: real frames exist only after
/// the pre-resolve pass, so a preview shows a faint, labelled box that marks
/// where the clip sits and how big its box is — what an author needs to
/// position it.
///
/// It fills the box the layout gives it, but — like Flutter's own
/// `RawImage`/`Image` when they have no intrinsic size — never demands infinite
/// size: the [LimitedBox] collapses it to zero on any axis the parent left
/// unbounded (which [ClipPainter]'s debug warning then explains) rather than
/// asserting. A self-contained [Directionality] lets the label render without
/// depending on an ambient text direction.
class _ClipPreviewPlaceholder extends StatelessWidget {
  const _ClipPreviewPlaceholder({required this.source});

  /// The clip being stood in for, used only to label the placeholder.
  final MediaSource source;

  @override
  Widget build(BuildContext context) {
    return LimitedBox(
      maxWidth: 0,
      maxHeight: 0,
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            border: Border.all(color: const Color(0x66FFFFFF), width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  '▶  ${_label(source)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A short human label for [source] — the file/asset basename, the URL's last
  /// segment, or a memory clip's debug label.
  String _label(MediaSource source) => switch (source) {
    AssetSource(:final name) => name.split('/').last,
    FileSource(:final path) => path.split(RegExp(r'[\\/]')).last,
    NetworkSource(:final url) => url.pathSegments.isNotEmpty ? url.pathSegments.last : url.host,
    MemorySource(:final debugLabel) => debugLabel ?? 'clip',
  };
}
