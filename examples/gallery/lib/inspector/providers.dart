import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/render_backend.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/lessons/lessons.dart';

/// Which lesson the inspector shows, as an index into [lessons].
///
/// The selection is the root of the inspector's provider graph: the playback
/// controller, the timeline probe, and the render target all derive from it,
/// so selecting a lesson swaps the whole right-hand side atomically.
final class SelectedLessonIndex extends Notifier<int> {
  @override
  int build() => 0;

  /// Selects the lesson at [index], clamped to the registry range.
  void select(int index) => state = index.clamp(0, lessons.length - 1);
}

/// The selected lesson index (see [SelectedLessonIndex]).
final selectedLessonIndexProvider = NotifierProvider<SelectedLessonIndex, int>(
  SelectedLessonIndex.new,
);

/// The selected [Lesson] itself.
final selectedLessonProvider = Provider<Lesson>(
  (ref) => lessons[ref.watch(selectedLessonIndexProvider)],
);

/// One [TimelineProbe] per selected lesson: the preview pane mounts it above
/// the `Video` and the inspector view model listens to it.
final timelineProbeProvider = Provider<TimelineProbe>((ref) {
  ref.watch(selectedLessonIndexProvider); // a fresh probe per lesson
  final probe = TimelineProbe();
  ref.onDispose(probe.dispose);
  return probe;
});

/// The render backend for this platform/config (local desktop or `fluvie_server`);
/// tests override this with a mock so no process or HTTP call happens.
final renderLauncherProvider = Provider<RenderLauncher>((ref) => createRenderLauncher());

/// Which workspace the inspector shows: a [lessons] entry or the AI Assistant.
enum WorkspaceMode {
  /// A selected lesson: the Code/Motions tabs and its cached preview.
  lesson,

  /// The AI Assistant: a prompt that generates and renders a video.
  aiAssistant,
}

/// Tracks the selected workspace; the left nav drives it and the centre stage
/// and right pane both switch on it.
final class WorkspaceModeNotifier extends Notifier<WorkspaceMode> {
  @override
  WorkspaceMode build() => WorkspaceMode.lesson;

  /// Shows a lesson (a lesson tap also selects which one).
  void showLesson() => state = WorkspaceMode.lesson;

  /// Shows the AI Assistant.
  void showAiAssistant() => state = WorkspaceMode.aiAssistant;
}

/// The selected workspace (see [WorkspaceModeNotifier]).
final workspaceModeProvider = NotifierProvider<WorkspaceModeNotifier, WorkspaceMode>(
  WorkspaceModeNotifier.new,
);
