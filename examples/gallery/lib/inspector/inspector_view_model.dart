import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/providers.dart';

/// The three states the inspector panel can be in.
sealed class InspectorState {
  const InspectorState();
}

/// Waiting for the preview's first resolution.
final class InspectorPending extends InspectorState {
  const InspectorPending();
}

/// The composition resolved successfully.
final class InspectorReady extends InspectorState {
  const InspectorReady(this.model);

  /// The resolved schedule, ready to render.
  final InspectorModel model;
}

/// The resolution failed with a [FluvieTimingError] (e.g. `Trigger.beat` with
/// no analysed grid in preview mode).
final class InspectorTimingError extends InspectorState {
  const InspectorTimingError(this.message);

  /// The [FluvieTimingError.message] from the failed resolution.
  final String message;
}

/// Builds the inspector state for the selected lesson: [InspectorPending]
/// before the preview resolves, [InspectorReady] on success, or
/// [InspectorTimingError] when `Video` catches a [FluvieTimingError].
///
/// Listens to the lesson's [TimelineProbe]; the `Video` pushes either a
/// [ResolvedTimeline] or an error into the probe after its resolution pass.
final class InspectorViewModel extends Notifier<InspectorState> {
  @override
  InspectorState build() {
    final probe = ref.watch(timelineProbeProvider);
    void push() => state = _stateFrom(probe);
    probe.addListener(push);
    ref.onDispose(() => probe.removeListener(push));
    return _stateFrom(probe);
  }

  static InspectorState _stateFrom(TimelineProbe probe) {
    if (probe.timingError != null) return InspectorTimingError(probe.timingError!);
    final timeline = probe.value;
    if (timeline == null) return const InspectorPending();
    return InspectorReady(InspectorModel.fromTimeline(timeline));
  }
}

/// The inspector view model and its [InspectorState].
final inspectorViewModelProvider = NotifierProvider<InspectorViewModel, InspectorState>(
  InspectorViewModel.new,
);
