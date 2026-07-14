part of 'presenter_shell.dart';

/// The shell's paint order, bottom to top: the hidden preview host (painted
/// but fully covered), the opaque stage color, the sidebar beside the
/// letterboxed slide, then the HUD, the overview grid, and the blanking
/// cover.
final class _ShellLayout extends ConsumerWidget {
  const _ShellLayout({
    required this.video,
    required this.stageBackground,
    required this.previewHostKey,
    required this.clockFactory,
    required this.handlers,
  });

  final Video video;
  final Color stageBackground;
  final GlobalKey<PreviewRenderHostState> previewHostKey;
  final LivePlaybackController Function(int fps)? clockFactory;
  final PresenterHandlers handlers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(slidePlansProvider);
    final aspect = video.width / video.height;
    return Stack(
      fit: StackFit.expand,
      children: [
        // The preview host paints first so its repaint boundary has pixels
        // to capture; the opaque stage color right above keeps it invisible.
        Positioned(
          top: 0,
          left: 0,
          child: PreviewRenderHost(key: previewHostKey, video: video, plans: plans),
        ),
        ColoredBox(color: stageBackground),
        Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SlideSidebar(aspectRatio: aspect),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: SlideView(video: video, clockFactory: clockFactory),
                        ),
                        StageHud(handlers: handlers),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const NotesPanel(),
          ],
        ),
        OverviewGrid(aspectRatio: aspect),
        const ScreenBlankOverlay(),
        const SpeakerFallbackNotice(),
      ],
    );
  }
}
