import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/inspector/providers.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';

/// What the render bar binds to: whether a render is running, its live frame
/// progress, and the last launch's combined output.
final class RenderState {
  /// Creates a render snapshot; the initial state is idle and silent.
  const RenderState({this.running = false, this.output = '', this.progress});

  /// True while the CLI process runs; the render button disables itself.
  final bool running;

  /// The last launch's stdout, stderr, and outcome line, newline-joined.
  final String output;

  /// Live capture progress while [running]; `null` before the first frame lands
  /// (the bar shows an indeterminate state until then) and once idle.
  final RenderProgress? progress;
}

/// Drives the injected [RenderLauncher] for the selected lesson (decision
/// D26): one render at a time, surfacing everything the CLI printed.
final class RenderViewModel extends Notifier<RenderState> {
  @override
  RenderState build() {
    ref.watch(selectedLessonProvider); // reset the output when the lesson changes
    return const RenderState();
  }

  /// Renders the selected lesson via the injected backend; no-op while one runs.
  ///
  /// The backend is chosen by configuration: a local desktop render (the Fluvie
  /// CLI, needs a Dart VM and ffmpeg) or a `fluvie_server` server (set
  /// `FLUVIE_API_URL`; the only option on web). A launch that throws (a missing
  /// `dart` on PATH raises a `ProcessException`, not a non-zero exit) is caught
  /// so the button never hangs on "Rendering ...".
  Future<void> render() async {
    if (state.running) return;
    final lesson = ref.read(selectedLessonProvider);
    final launcher = ref.read(renderLauncherProvider);
    const status = 'Rendering';
    // Seed the total up front (the composition's frame count) so the bar is
    // determinate and shows "0 / N (0%)" immediately — through the seconds of
    // `flutter test` startup before the first captured frame lands. The live
    // count from the launcher then replaces it (and corrects the total if a
    // draft render captures fewer frames).
    final total = lesson.video().totalFrames;
    state = RenderState(
      running: true,
      output: '$status ...',
      progress: RenderProgress(completed: 0, total: total),
    );
    try {
      final result = await launcher.render(
        lesson.id,
        onProgress: (progress) {
          if (!ref.mounted || !state.running) return;
          state = RenderState(running: true, output: '$status ...', progress: progress);
        },
      );
      if (!ref.mounted) return;
      state = RenderState(output: _describe(lesson.id, result));
    } on Exception catch (error) {
      if (!ref.mounted) return;
      state = RenderState(output: 'Render failed: $error');
    }
  }

  static String _describe(String key, RenderLaunchResult result) => [
    if (result.stdout.trim().isNotEmpty) result.stdout.trim(),
    if (result.stderr.trim().isNotEmpty) result.stderr.trim(),
    if (result.exitCode != 0)
      'Render failed with exit code ${result.exitCode}'
    else if (result.downloadUrl != null)
      'Download: ${result.downloadUrl}'
    else
      'Wrote build/$key.mp4',
  ].join('\n');
}

/// The render view model and its state.
final renderViewModelProvider = NotifierProvider<RenderViewModel, RenderState>(
  RenderViewModel.new,
);
