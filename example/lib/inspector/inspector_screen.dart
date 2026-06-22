import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/inspector/generate_screen.dart';
import 'package:fluvie_example/inspector/inspector_panel.dart';
import 'package:fluvie_example/inspector/playback_view_model.dart';
import 'package:fluvie_example/inspector/preview_pane.dart';
import 'package:fluvie_example/inspector/providers.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/inspector/render_view_model.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/playground/playground.dart';

/// The inspector: the lesson list on the left, the scrubbable preview
/// in the middle, and the structured [InspectorPanel] on the right.
///
/// Every pane is its own consumer, so a scrub rebuilds only the playback bar
/// (the preview repaints through its frame clock, not through this tree) and
/// a lesson tap swaps all three panes through the selection provider.
final class InspectorScreen extends StatelessWidget {
  /// Creates the inspector screen.
  const InspectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fluvie inspector'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate with AI',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GenerateScreen()),
              ),
            ),
          ),
        ],
      ),
      body: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 260, child: _LessonList()),
          VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: PreviewPane()),
                _PlaybackBar(),
                _RenderBar(),
              ],
            ),
          ),
          VerticalDivider(width: 1),
          Expanded(flex: 2, child: _RightPane()),
        ],
      ),
    );
  }
}

/// The right pane: a Code tab hosting the [Playground] (the default) and a
/// Motions tab hosting the structured [InspectorPanel].
final class _RightPane extends StatelessWidget {
  const _RightPane();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Code', icon: Icon(Icons.code)),
              Tab(text: 'Motions', icon: Icon(Icons.movie_filter)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [Playground(), InspectorPanel()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The lessons, in registry order; tapping one selects it everywhere.
final class _LessonList extends ConsumerWidget {
  const _LessonList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLessonIndexProvider);
    return ListView(
      children: [
        for (var index = 0; index < lessons.length; index++)
          ListTile(
            selected: index == selected,
            title: Text(lessons[index].title),
            subtitle: Text(lessons[index].intro, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => ref.read(selectedLessonIndexProvider.notifier).select(index),
          ),
      ],
    );
  }
}

/// The scrubber: a slider, play/pause button, frame readout, and FPS selector.
final class _PlaybackBar extends ConsumerWidget {
  const _PlaybackBar();

  static const _fpsOptions = [5, 10, 15, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackViewModelProvider);
    final notifier = ref.read(playbackViewModelProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: playback.frame.toDouble(),
            max: (playback.totalFrames - 1).toDouble(),
            onChanged: (value) => notifier.seek(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
                tooltip: playback.isPlaying ? 'Pause' : 'Play',
                onPressed: playback.isPlaying ? notifier.pause : notifier.play,
              ),
              Text('frame ${playback.frame} / ${playback.totalFrames - 1}'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: playback.playFps,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final fps in _fpsOptions)
                    DropdownMenuItem<int>(
                      value: fps,
                      child: Text(
                        '$fps fps',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
                onChanged: (fps) {
                  if (fps != null) notifier.setPlayFps(fps);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The render button and the last launch's output.
final class _RenderBar extends ConsumerWidget {
  const _RenderBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final render = ref.watch(renderViewModelProvider);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: render.running
                ? null
                : () => unawaited(ref.read(renderViewModelProvider.notifier).render()),
            child: const Text('Render MP4'),
          ),
          if (render.running)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _RenderProgress(progress: render.progress),
            ),
          if (render.output.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(render.output, style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The live render progress: a bar plus an "N / M frames" readout, shown under
/// the render button while a render runs. Before the first frame lands (or once
/// every frame is captured and ffmpeg is encoding) the bar is indeterminate.
final class _RenderProgress extends StatelessWidget {
  const _RenderProgress({required this.progress});

  final RenderProgress? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final encoding = progress != null && progress.isComplete;
    final String label;
    final double? value;
    if (progress == null) {
      // Only before the total is known (it is seeded up front, so this is rare).
      label = 'Starting ...';
      value = null;
    } else if (encoding) {
      // Every frame captured; ffmpeg is muxing. Hold the bar full, not back to
      // indeterminate, so it never appears to "restart".
      label = 'Encoding ...';
      value = 1;
    } else {
      label =
          '${progress.completed} / ${progress.total} frames '
          '(${(progress.fraction * 100).round()}%)';
      value = progress.fraction;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: value),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
