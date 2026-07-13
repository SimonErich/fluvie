import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/navigation_kind.dart';
import 'package:fluvie_presenter/src/controller/presentation_position.dart';
import 'package:fluvie_presenter/src/controller/presentation_state.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';

/// The compiled deck the presentation traverses — one plan per slide.
///
/// The presenter shell overrides this with the result of
/// `compileSlidePlans(video)`; reading it unoverridden is a wiring bug.
final slidePlansProvider = Provider<List<SlidePlan>>(
  (ref) => throw UnimplementedError(
    'slidePlansProvider must be overridden with the compiled deck '
    '(compileSlidePlans(video)) before the presentation can navigate.',
  ),
);

/// The presentation's navigation state.
final presentationControllerProvider = NotifierProvider<PresentationController, PresentationState>(
  PresentationController.new,
);

/// Walks a compiled deck: forward advances reveal steps, backward moves and
/// jumps land on held states.
///
/// The controller holds only navigable state — `(slide, step)` and how it
/// was reached. Everything time-related (the slide clock, reveal frames,
/// entrance playback) belongs to the slide view, which renders this state.
final class PresentationController extends Notifier<PresentationState> {
  @override
  PresentationState build() => const PresentationState(
    position: PresentationPosition(0, 0),
    lastMove: NavigationKind.instant,
  );

  List<SlidePlan> get _plans => ref.read(slidePlansProvider);

  /// How many slides the deck has.
  int get totalSlides => _plans.length;

  /// How many steps the current slide has (its stops plus one).
  int get stepsInCurrentSlide => _plans[state.position.slide].stepCount;

  /// The position the next input produces, or `null` at the end of the deck.
  PresentationPosition? get nextPosition {
    final position = state.position;
    if (position.step + 1 < _plans[position.slide].stepCount) {
      return PresentationPosition(position.slide, position.step + 1);
    }
    if (position.slide + 1 < _plans.length) {
      return PresentationPosition(position.slide + 1, 0);
    }
    return null;
  }

  /// The position `back` lands on, or `null` at the start of the deck.
  PresentationPosition? get previousPosition {
    final position = state.position;
    if (position.step > 0) {
      return PresentationPosition(position.slide, position.step - 1);
    }
    if (position.slide > 0) {
      return PresentationPosition(position.slide - 1, _plans[position.slide - 1].stepCount - 1);
    }
    return null;
  }

  /// Whether a forward advance changes anything.
  bool get canGoNext => nextPosition != null;

  /// Whether a backward move changes anything.
  bool get canGoBack => previousPosition != null;

  /// Advances one step (or to the next slide's base step), playing the
  /// authored entrance. A no-op at the end of the deck.
  void next() {
    final target = nextPosition;
    if (target == null) return;
    state = PresentationState(position: target, lastMove: NavigationKind.forward);
  }

  /// Goes back one position, landing on its held state instantly. A no-op at
  /// the start of the deck.
  void back() {
    final target = previousPosition;
    if (target == null) return;
    state = PresentationState(position: target, lastMove: NavigationKind.instant);
  }

  /// Jumps to [slide] at its base step, instantly. Out-of-range indexes
  /// clamp to the deck.
  void jumpToSlide(int slide) => jumpToStep(slide, 0);

  /// Jumps to [step] of [slide], instantly. Out-of-range indexes clamp to
  /// the deck and the slide.
  void jumpToStep(int slide, int step) {
    final boundedSlide = slide.clamp(0, _plans.length - 1);
    final boundedStep = step.clamp(0, _plans[boundedSlide].stepCount - 1);
    state = PresentationState(
      position: PresentationPosition(boundedSlide, boundedStep),
      lastMove: NavigationKind.instant,
    );
  }
}
