import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/slide_view.dart';
import 'package:fluvie_presenter/src/stepping/step_compiler.dart';

/// The presenter: hand it a [Video] and present it.
///
/// ```dart
/// runApp(FluvieSlides(video));
/// ```
///
/// One scene is one slide; `Stop`s inside a scene become its build steps.
/// The viewer compiles the deck once, owns the presentation state, and
/// renders the current position through a [SlideView]. Input, chrome, the
/// sidebar, notes, and the speaker window arrive phase by phase on this same
/// shell; the constructor already carries the minimal config surface so
/// callers never migrate.
final class FluvieSlides extends StatefulWidget {
  /// Presents [video].
  const FluvieSlides(
    this.video, {
    this.showSidebar = false,
    this.showNotes = false,
    this.startFullscreen = false,
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

  @override
  State<FluvieSlides> createState() => _FluvieSlidesState();
}

final class _FluvieSlidesState extends State<FluvieSlides> {
  late List<SlidePlan> _plans = compileSlidePlans(widget.video);

  @override
  void didUpdateWidget(FluvieSlides oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.video, widget.video)) {
      _plans = compileSlidePlans(widget.video);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = ColoredBox(
      color: const Color(0xFF101014),
      child: Center(child: SlideView(video: widget.video)),
    );
    // Keyed by the deck: swapping the video remounts the whole presentation
    // scope, so navigation state and mounted slides start fresh.
    final scoped = ProviderScope(
      key: ObjectKey(widget.video),
      overrides: [slidePlansProvider.overrideWithValue(_plans)],
      child: stage,
    );
    // The presenter can be someone's whole runApp: give the stage a text
    // direction when no app shell above provides one.
    return Directionality.maybeOf(context) == null
        ? Directionality(textDirection: TextDirection.ltr, child: scoped)
        : scoped;
  }
}
