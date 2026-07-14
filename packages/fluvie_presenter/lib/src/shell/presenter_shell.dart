import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController, Video;
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/notes/notes_panel.dart';
import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';
import 'package:fluvie_presenter/src/shell/presentation_shortcuts.dart';
import 'package:fluvie_presenter/src/shell/presenter_theme.dart';
import 'package:fluvie_presenter/src/shell/screen_blank.dart';
import 'package:fluvie_presenter/src/shell/stage_hud.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/sidebar/overview_grid.dart';
import 'package:fluvie_presenter/src/sidebar/preview_render_host.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';
import 'package:fluvie_presenter/src/sidebar/slide_sidebar.dart';
import 'package:fluvie_presenter/src/speaker/speaker_fallback.dart';
import 'package:fluvie_presenter/src/speaker/speaker_sync_binding.dart';
import 'package:fluvie_presenter/src/speaker/speaker_window_launcher.dart';
import 'package:fluvie_presenter/src/stepping/slide_view.dart';
import 'package:obers_ui/obers_ui.dart' show OiDensity, OiDensityScope, OiThemeScope;

part 'presenter_shell_layout.dart';

/// The stage everything presents on: the letterboxed slide under the input
/// layer, the sidebar beside it, and the HUD, overview, and blanking
/// overlays on top.
///
/// The shell wires input to the presentation controller and the chrome
/// state — nothing more. It mounts its own obers_ui theme scope, so the
/// chrome renders the same whether the presenter is embedded in an `OiApp`
/// or is somebody's whole `runApp`.
final class PresenterShell extends ConsumerStatefulWidget {
  /// Creates the shell for [video].
  const PresenterShell({
    required this.video,
    this.startFullscreen = false,
    this.onClose,
    this.clockFactory,
    this.previewService,
    super.key,
  });

  /// The authored deck.
  final Video video;

  /// Whether the shell requests fullscreen once mounted.
  final bool startFullscreen;

  /// Ends the presentation; when set, the HUD strip shows a close button.
  final VoidCallback? onClose;

  /// A test seam forwarded to the slide view, so goldens hold deterministic
  /// frames. `null` (production) free-runs.
  final LivePlaybackController Function(int fps)? clockFactory;

  /// A test seam replacing the host-bound preview service; the caller owns
  /// its lifecycle. `null` (production) renders on the hidden host.
  final SlidePreviewService? previewService;

  @override
  ConsumerState<PresenterShell> createState() => _PresenterShellState();
}

final class _PresenterShellState extends ConsumerState<PresenterShell> {
  final GlobalKey<PreviewRenderHostState> _previewHost = GlobalKey();
  late final SlidePreviewService _previews =
      widget.previewService ??
      SlidePreviewService(
        concurrency: 1,
        renderSlide: (slide) => _previewHost.currentState!.render(slide),
      );

  @override
  void initState() {
    super.initState();
    if (widget.startFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_enterFullscreen());
      });
    }
  }

  @override
  void didUpdateWidget(PresenterShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new deck means every cached thumbnail shows stale content.
    if (!identical(widget.video, oldWidget.video)) _previews.invalidate();
  }

  @override
  void dispose() {
    if (widget.previewService == null) _previews.dispose();
    super.dispose();
  }

  /// Clears the topmost overlay (blank screen, speaker fallback, then the
  /// overview). Returns whether anything was cleared — navigation and escape
  /// consume the input when it was.
  bool _clearOverlays() {
    if (ref.read(blankScreenProvider) != null) {
      ref.read(blankScreenProvider.notifier).clear();
      return true;
    }
    if (ref.read(speakerFallbackProvider) != null) {
      ref.read(speakerFallbackProvider.notifier).clear();
      return true;
    }
    if (ref.read(overviewVisibleProvider)) {
      ref.read(overviewVisibleProvider.notifier).visible = false;
      return true;
    }
    return false;
  }

  Future<void> _enterFullscreen() async {
    await ref.read(fullscreenControllerProvider).enter();
    await _trackFullscreen();
  }

  Future<void> _toggleFullscreen() async {
    await ref.read(fullscreenControllerProvider).toggle();
    await _trackFullscreen();
  }

  Future<void> _exitFullscreen() async {
    await ref.read(fullscreenControllerProvider).exit();
    await _trackFullscreen();
  }

  /// Re-reads the platform truth after a transition, so the tracked state
  /// stays honest even when a request was refused (web needs a gesture).
  Future<void> _trackFullscreen() async {
    final active = await ref.read(fullscreenControllerProvider).isFullscreen;
    if (mounted) ref.read(fullscreenActiveProvider.notifier).visible = active;
  }

  /// S: mobile has no second window, so the in-app notes panel is the
  /// speaker surface; everywhere else the launcher tries, and a refusal
  /// becomes the open-this-URL instruction.
  Future<void> _openSpeakerWindow() async {
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (mobile) {
      ref.read(notesVisibleProvider.notifier).visible = true;
      return;
    }
    final result = await ref.read(speakerWindowLauncherProvider).open();
    if (result.opened || !mounted) return;
    ref.read(speakerFallbackProvider.notifier).show(url: result.url);
  }

  PresenterHandlers _handlers() {
    final controller = ref.read(presentationControllerProvider.notifier);
    return PresenterHandlers(
      onNext: () {
        if (_clearOverlays()) return;
        controller.next();
      },
      onBack: () {
        if (_clearOverlays()) return;
        controller.back();
      },
      onFirst: () => controller.jumpToSlide(0),
      onLast: () => controller.jumpToSlide(controller.totalSlides - 1),
      onJump: controller.jumpToSlide,
      onToggleFullscreen: () => unawaited(_toggleFullscreen()),
      onEscape: () {
        if (_clearOverlays()) return;
        unawaited(_exitFullscreen());
      },
      onOverview: () => ref.read(overviewVisibleProvider.notifier).toggle(),
      onSpeakerWindow: () => unawaited(_openSpeakerWindow()),
      onBlackScreen: () => ref.read(blankScreenProvider.notifier).toggle(BlankScreen.black),
      onWhiteScreen: () => ref.read(blankScreenProvider.notifier).toggle(BlankScreen.white),
      onToggleHud: () => ref.read(hudVisibleProvider.notifier).toggle(),
      onToggleSidebar: () => ref.read(sidebarVisibleProvider.notifier).toggle(),
      onToggleNotes: () => ref.read(notesVisibleProvider.notifier).toggle(),
      onClose: widget.onClose,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(presenterThemeProvider);
    final handlers = _handlers();
    Widget shell = OiThemeScope(
      data: theme.resolveTokens(),
      child: ProviderScope(
        overrides: [slidePreviewServiceProvider.overrideWithValue(_previews)],
        child: PresentationShortcuts(
          handlers: handlers,
          child: SpeakerSyncBinding(
            // The shell brings its own Overlay (like its own theme scope),
            // so tooltips work without an OiApp or Navigator above.
            child: Overlay.wrap(
              child: _ShellLayout(
                video: widget.video,
                stageBackground: theme.stageBackground,
                previewHostKey: _previewHost,
                clockFactory: widget.clockFactory,
                handlers: handlers,
              ),
            ),
          ),
        ),
      ),
    );
    // The chrome's buttons read the ambient density; standalone shells
    // (no OiApp above) get a sensible default without shadowing a host's.
    if (context.dependOnInheritedWidgetOfExactType<OiDensityScope>() == null) {
      shell = OiDensityScope(density: OiDensity.compact, child: shell);
    }
    return shell;
  }
}
