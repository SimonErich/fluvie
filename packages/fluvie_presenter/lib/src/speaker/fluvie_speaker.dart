import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:fluvie_presenter/src/notes/notes_compiler.dart';
import 'package:fluvie_presenter/src/notes/slide_notes.dart';
import 'package:fluvie_presenter/src/shell/presentation_shortcuts.dart';
import 'package:fluvie_presenter/src/shell/presenter_theme.dart';
import 'package:fluvie_presenter/src/speaker/presentation_sync_channel.dart';
import 'package:fluvie_presenter/src/speaker/speaker_sync_binding.dart';
import 'package:fluvie_presenter/src/speaker/speaker_view.dart';
import 'package:fluvie_presenter/src/speaker/sync_message.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/step_compiler.dart';
import 'package:obers_ui/obers_ui.dart' show OiThemeScope;

/// The speaker window's root: mount this for [video] on the speaker route
/// (the web popup, a second desktop window, or anywhere you want the
/// speaker screen instead of the stage).
///
/// ```dart
/// runApp(FluvieSpeaker(video));
/// ```
///
/// It compiles the same deck the presenter compiles, follows the presenting
/// window over the sync channel, and sends its own inputs back as
/// navigation requests — either window can advance.
final class FluvieSpeaker extends StatefulWidget {
  /// Creates the speaker root for [video].
  const FluvieSpeaker(this.video, {this.theme, super.key});

  /// The authored deck — the same one the presenting window shows.
  final Video video;

  /// The chrome look, or `null` for the flat dark default.
  final PresenterTheme? theme;

  @override
  State<FluvieSpeaker> createState() => _FluvieSpeakerState();
}

final class _FluvieSpeakerState extends State<FluvieSpeaker> {
  late List<SlidePlan> _plans = compileSlidePlans(widget.video);
  late List<List<SlideNotes>> _notes = compileNotes(widget.video, _plans);

  @override
  void didUpdateWidget(FluvieSpeaker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.video, widget.video)) {
      _plans = compileSlidePlans(widget.video);
      _notes = compileNotes(widget.video, _plans);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoped = ProviderScope(
      key: ObjectKey(widget.video),
      overrides: [
        slidePlansProvider.overrideWithValue(_plans),
        slideNotesProvider.overrideWithValue(_notes),
        // The controller must live in THIS scope (where the deck is), even
        // when a host app mounts its own ProviderScope above.
        presentationControllerProvider.overrideWith(PresentationController.new),
        if (widget.theme != null) presenterThemeProvider.overrideWithValue(widget.theme!),
      ],
      child: _SpeakerShell(video: widget.video),
    );
    Widget wrapped = scoped;
    if (MediaQuery.maybeOf(context) == null) {
      wrapped = MediaQuery.fromView(view: View.of(context), child: wrapped);
    }
    if (Directionality.maybeOf(context) == null) {
      wrapped = Directionality(textDirection: TextDirection.ltr, child: wrapped);
    }
    return wrapped;
  }
}

final class _SpeakerShell extends ConsumerWidget {
  const _SpeakerShell({required this.video});

  final Video video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(presenterThemeProvider);
    final channel = ref.read(presentationSyncChannelProvider);
    final controller = ref.read(presentationControllerProvider.notifier);
    // With a channel, inputs travel to the presenting window and the
    // position comes back; without one this window navigates itself.
    void request(SyncMessage message, VoidCallback local) =>
        channel == null ? local() : channel.send(message);
    return OiThemeScope(
      data: theme.resolveTokens(),
      child: PresentationShortcuts(
        handlers: PresenterHandlers(
          onNext: () => request(const NavigationRequest.next(), controller.next),
          onBack: () => request(const NavigationRequest.back(), controller.back),
          onFirst: () => request(
            const NavigationRequest.jump(PresentationPosition(0, 0)),
            () => controller.jumpToSlide(0),
          ),
          onLast: () => request(
            NavigationRequest.jump(PresentationPosition(controller.totalSlides - 1, 0)),
            () => controller.jumpToSlide(controller.totalSlides - 1),
          ),
          onJump: (slide) => request(
            NavigationRequest.jump(PresentationPosition(slide, 0)),
            () => controller.jumpToSlide(slide),
          ),
          // The speaker window has no stage chrome of its own to drive.
          onToggleFullscreen: () {},
          onEscape: () {},
          onOverview: () {},
          onSpeakerWindow: () {},
          onBlackScreen: () {},
          onWhiteScreen: () {},
          onToggleHud: () {},
          onToggleSidebar: () {},
          onToggleNotes: () {},
        ),
        child: SpeakerSyncBinding(
          isPrimary: false,
          child: SpeakerView(video: video),
        ),
      ),
    );
  }
}
