part of 'slide_strip.dart';

/// One slide thumbnail: the cached preview (requested lazily), the index,
/// and the current-slide accent.
final class _SlideTile extends StatelessWidget {
  const _SlideTile({
    required this.index,
    required this.current,
    required this.service,
    required this.onTap,
    required this.menuItems,
    this.masterName,
    super.key,
  });

  final int index;
  final bool current;
  final SlidePreviewService service;
  final VoidCallback onTap;
  final List<OiMenuItem> menuItems;

  /// The master this slide adopts, or null — adopting tiles badge
  /// themselves with a small chip over the thumbnail.
  final String? masterName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OiContextMenu(
      label: 'Slide ${index + 1} menu',
      items: menuItems,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              final image = service.peek(index);
              if (image == null) unawaited(service.preview(index).then((_) {}, onError: (_) {}));
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: current ? colors.accent.base : colors.borderSubtle,
                    width: current ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: OiLabel.small('${index + 1}', color: colors.textSubtle),
                    ),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (image != null) RawImage(image: image, fit: BoxFit.contain),
                          if (masterName != null)
                            Positioned(
                              left: 2,
                              bottom: 2,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  child: OiLabel.small('M $masterName', color: colors.textSubtle),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
