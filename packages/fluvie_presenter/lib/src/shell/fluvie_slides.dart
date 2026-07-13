import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/notes/notes_compiler.dart';
import 'package:fluvie_presenter/src/notes/slide_notes.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/shell/presenter_theme.dart';
import 'package:fluvie_presenter/src/shell/ui_state.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/step_compiler.dart';

/// The presenter: hand it a [Video] and present it.
///
/// ```dart
/// runApp(FluvieSlides(video));
/// ```
///
/// One scene is one slide; `Stop`s inside a scene become its build steps.
/// The viewer compiles the deck once, owns the presentation state, and
/// renders the stage through a [PresenterShell]. It works as a whole app or
/// embedded in one: missing ambient scopes (text direction, media query) are
/// provided when absent.
final class FluvieSlides extends StatefulWidget {
  /// Presents [video].
  const FluvieSlides(
    this.video, {
    this.showSidebar = false,
    this.showNotes = false,
    this.startFullscreen = false,
    this.theme,
    super.key,
  });

  /// The presentation: a plain fluvie composition, one scene per slide.
  final Video video;

  /// Whether the slide sidebar starts visible.
  final bool showSidebar;

  /// Whether the speaker-notes panel starts visible.
  final bool showNotes;

  /// Whether presenting starts in fullscreen.
  final bool startFullscreen;

  /// The presenter's look, or `null` for the flat dark default.
  final PresenterTheme? theme;

  @override
  State<FluvieSlides> createState() => _FluvieSlidesState();
}

final class _FluvieSlidesState extends State<FluvieSlides> {
  late List<SlidePlan> _plans = compileSlidePlans(widget.video);
  late List<List<SlideNotes>> _notes = compileNotes(widget.video, _plans);

  @override
  void didUpdateWidget(FluvieSlides oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.video, widget.video)) {
      _plans = compileSlidePlans(widget.video);
      _notes = compileNotes(widget.video, _plans);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keyed by the deck: swapping the video remounts the whole presentation
    // scope, so navigation state and mounted slides start fresh.
    final scoped = ProviderScope(
      key: ObjectKey(widget.video),
      overrides: [
        slidePlansProvider.overrideWithValue(_plans),
        slideNotesProvider.overrideWithValue(_notes),
        if (widget.theme != null) presenterThemeProvider.overrideWithValue(widget.theme!),
        sidebarVisibleProvider.overrideWith(() => UiToggle(initiallyVisible: widget.showSidebar)),
        notesVisibleProvider.overrideWith(() => UiToggle(initiallyVisible: widget.showNotes)),
      ],
      child: PresenterShell(video: widget.video, startFullscreen: widget.startFullscreen),
    );
    return _withAmbientScopes(context, scoped);
  }

  /// The presenter can be someone's whole `runApp`: provide the ambient
  /// scopes chrome needs (text direction, media metrics) when no app shell
  /// above already does.
  Widget _withAmbientScopes(BuildContext context, Widget child) {
    var wrapped = child;
    if (MediaQuery.maybeOf(context) == null) {
      wrapped = MediaQuery.fromView(view: View.of(context), child: wrapped);
    }
    if (Directionality.maybeOf(context) == null) {
      wrapped = Directionality(textDirection: TextDirection.ltr, child: wrapped);
    }
    return wrapped;
  }
}
