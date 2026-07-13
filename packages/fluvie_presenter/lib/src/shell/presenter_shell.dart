import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController, Video;
import 'package:fluvie_presenter/src/shell/presenter_theme.dart';
import 'package:fluvie_presenter/src/shell/stage_hud.dart';
import 'package:fluvie_presenter/src/stepping/slide_view.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeScope;

/// The stage everything presents on: the letterboxed slide, the HUD, and
/// (as the phases land) the input layer, overlays, sidebar, and notes panel.
///
/// The shell mounts its own obers_ui theme scope, so the chrome renders the
/// same whether the presenter is embedded in an `OiApp` or is somebody's
/// whole `runApp`.
final class PresenterShell extends ConsumerWidget {
  /// Creates the shell for [video].
  const PresenterShell({required this.video, this.clockFactory, super.key});

  /// The authored deck.
  final Video video;

  /// A test seam forwarded to the slide view, so goldens hold deterministic
  /// frames. `null` (production) free-runs.
  final LivePlaybackController Function(int fps)? clockFactory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(presenterThemeProvider);
    return OiThemeScope(
      data: theme.resolveTokens(),
      child: ColoredBox(
        color: theme.stageBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: SlideView(video: video, clockFactory: clockFactory),
            ),
            const StageHud(),
          ],
        ),
      ),
    );
  }
}
