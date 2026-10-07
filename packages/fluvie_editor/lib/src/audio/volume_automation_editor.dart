import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart'
    show AudioAutomation, FrameSpan, encodeAudioAutomation, namedEases;
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

/// An accessible numeric editor for volume stops, time and per-segment easing.
/// The callback writes ordinary V5 automation JSON, usable for tracks and clips.
final class VolumeAutomationEditor extends StatelessWidget {
  /// Edits one [automation] over its audible [span].
  const VolumeAutomationEditor({
    required this.automation,
    required this.span,
    required this.fps,
    required this.currentFrame,
    required this.onChanged,
    super.key,
  });

  /// Current authored envelope.
  final AudioAutomation automation;

  /// Absolute audible window.
  final FrameSpan span;

  /// Composition frame rate.
  final int fps;

  /// Absolute playhead frame, where a new stop is inserted.
  final int currentFrame;

  /// Receives replacement automation, or null to clear it.
  final ValueChanged<Map<String, Object?>?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scope = OwnerFrameScope(fps, span);
    final frames = [for (final position in automation.positions) position.resolveFrames(scope)];
    final rawVolume = encodeAudioAutomation(automation)['volume'];
    final curves = rawVolume is Map<String, Object?> && rawVolume['easings'] is List
        ? List<Object?>.of(rawVolume['easings']! as List)
        : List<Object?>.filled(
            automation.values.length > 1 ? automation.values.length - 1 : 0,
            'linear',
          );
    void commit(List<double> values, List<int> times, List<Object?> easings) => onChanged(
      values.isEmpty
          ? null
          : {
              'volume': values.length == 1
                  ? values.single
                  : {
                      'values': values,
                      'positions': [for (final frame in times) '${frame}f'],
                      if (easings.any((e) => e != 'linear')) 'easings': easings,
                    },
            },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < automation.values.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MathNumberInput(
                        label: 'Stop ${i + 1} gain',
                        value: automation.values[i],
                        min: 0,
                        max: 1,
                        step: 0.05,
                        decimals: 2,
                        onChanged: (value) {
                          final next = [...automation.values];
                          next[i] = value;
                          commit(next, frames, curves);
                        },
                      ),
                    ),
                    OiIconButton(
                      icon: OiIcons.trash,
                      semanticLabel: 'Remove volume stop ${i + 1}',
                      onTap: () {
                        final values = [...automation.values]..removeAt(i);
                        final times = [...frames];
                        if (times.isNotEmpty) times.removeAt(i);
                        final easings = [...curves];
                        if (easings.isNotEmpty) easings.removeAt(i.clamp(0, easings.length - 1));
                        commit(values, times, easings);
                      },
                    ),
                  ],
                ),
                if (frames.length > 1)
                  MathNumberInput(
                    label: 'Stop ${i + 1} frame',
                    value: frames[i].toDouble(),
                    min: (i == 0 ? 0 : frames[i - 1] + 1).toDouble(),
                    max: (i == frames.length - 1 ? span.durationFrames : frames[i + 1] - 1)
                        .toDouble(),
                    decimals: 0,
                    onChanged: (value) {
                      final next = [...frames];
                      next[i] = value.round();
                      commit(automation.values, next, curves);
                    },
                  ),
                if (i < curves.length)
                  OiSelect<String>(
                    label: 'To stop ${i + 2}',
                    value: curves[i] is String ? curves[i]! as String : 'custom',
                    options: [
                      if (curves[i] is! String)
                        const OiSelectOption(value: 'custom', label: 'Custom cubic'),
                      for (final name in namedEases.keys) OiSelectOption(value: name, label: name),
                    ],
                    onChanged: (value) {
                      if (value == null || value == 'custom') return;
                      final next = [...curves];
                      next[i] = value;
                      commit(automation.values, frames, next);
                    },
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            OiButton.ghost(
              label: 'Add volume stop',
              onTap: () {
                final frame = (currentFrame - span.start).clamp(0, span.durationFrames);
                final keyed = <int, double>{};
                if (automation.values.length < 2) {
                  final value = automation.values.isEmpty ? 1.0 : automation.values.single;
                  keyed[0] = value;
                  keyed[span.durationFrames] = value;
                } else {
                  for (var i = 0; i < frames.length; i++) {
                    keyed[frames[i]] = automation.values[i];
                  }
                }
                keyed[frame] = 0.5;
                final ordered = keyed.keys.toList()..sort();
                // Preserve a segment's easing when inserting a stop into it.
                final easings = <Object?>[];
                for (var i = 0; i < ordered.length - 1; i++) {
                  Object? curve = 'linear';
                  for (var j = 0; j < curves.length; j++) {
                    if (ordered[i] >= frames[j] && ordered[i] < frames[j + 1]) {
                      curve = curves[j];
                      break;
                    }
                  }
                  easings.add(curve);
                }
                commit([for (final f in ordered) keyed[f]!], ordered, easings);
              },
            ),
            if (!automation.isEmpty)
              OiButton.ghost(label: 'Clear automation', onTap: () => onChanged(null)),
          ],
        ),
      ],
    );
  }
}
