part of 'start_screen.dart';

/// The desktop shape: a tall brand band, a fixed action rail on the left,
/// and the working column (recents, templates) on the right.
final class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.scroll, required this.actions, required this.body});

  final ScrollController scroll;
  final Widget actions;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const StartHero(height: 180),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 24, 24),
                child: actions,
              ),
            ),
            const OiDivider(axis: Axis.vertical),
            Expanded(
              child: OiScrollbar(
                controller: scroll,
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(32, 28, 40, 40),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The narrow shape: one scrolling column, actions first so the two primary
/// buttons are never pushed below the fold.
final class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.scroll, required this.actions, required this.body});

  final ScrollController scroll;
  final Widget actions;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) => OiScrollbar(
    controller: scroll,
    child: SingleChildScrollView(
      controller: scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StartHero(height: 140),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [actions, const SizedBox(height: 28), ...body],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
