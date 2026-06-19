import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/inspector/inspector_view_model.dart';
import 'package:fluvie_example/inspector/playback_view_model.dart';

/// The structured inspector panel: renders the selected lesson's
/// [InspectorModel] as a timing warnings band, a tappable anchor list, and the
/// resolved motion rows.
///
/// Tapping an anchor or a motion row seeks the preview to that frame
/// (jump-to-trigger) through the [PlaybackViewModel]. The model arrives
/// through the [InspectorViewModel], which the preview's `Video` feeds via the
/// timeline probe; until the first resolution lands the panel shows a pending
/// hint, and a [FluvieTimingError] shows a structured error view.
final class InspectorPanel extends ConsumerWidget {
  /// Creates the inspector panel.
  const InspectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectorViewModelProvider);
    void seek(int frame) => ref.read(playbackViewModelProvider.notifier).seek(frame);
    return switch (state) {
      InspectorPending() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Timeline pending: the preview resolves it after its first frame.'),
        ),
      ),
      InspectorTimingError(:final message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Text('Timing error', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      InspectorReady(:final model) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Header('Resolved schedule', subtitle: '${model.totalFrames} frames @ ${model.fps} fps'),
          if (model.warnings.isNotEmpty) _WarningsBand(warnings: model.warnings),
          if (model.anchors.isNotEmpty) ...[
            const _Header('Anchors'),
            for (final anchor in model.anchors) _AnchorRow(anchor: anchor, onJump: seek),
          ],
          const _Header('Motions'),
          for (final motion in model.motions) _MotionRow(motion: motion, onJump: seek),
        ],
      ),
    };
  }
}

/// A section heading with an optional [subtitle].
final class _Header extends StatelessWidget {
  const _Header(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// The timing-warnings band: one line per resolver warning.
final class _WarningsBand extends StatelessWidget {
  const _WarningsBand({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'warning: $warning',
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tappable anchor row: seeks the preview to the anchor's frame.
final class _AnchorRow extends StatelessWidget {
  const _AnchorRow({required this.anchor, required this.onJump});

  final TimelineAnchor anchor;
  final void Function(int frame) onJump;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: const Icon(Icons.anchor, size: 18),
    title: Text(anchor.name),
    trailing: Text('frame ${anchor.frame}'),
    onTap: () => onJump(anchor.frame),
  );
}

/// One tappable motion row: seeks the preview to the motion's jump
/// frame and shows its owner, label, phase, and span.
final class _MotionRow extends StatelessWidget {
  const _MotionRow({required this.motion, required this.onJump});

  final InspectorMotion motion;
  final void Function(int frame) onJump;

  @override
  Widget build(BuildContext context) {
    final label = motion.label == null
        ? motion.phase.name
        : '${motion.label} (${motion.phase.name})';
    return ListTile(
      dense: true,
      leading: const Icon(Icons.movie_filter, size: 18),
      title: Text(motion.ownerId),
      subtitle: Text(label),
      trailing: Text('${motion.startFrame}..${motion.endFrame}'),
      onTap: () => onJump(motion.jumpFrame),
    );
  }
}
