import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import '../example_base.dart';
import 'controls_panel.dart';
import 'theme.dart';

/// Provider for current preview frame
final previewFrameProvider = StateProvider<int>((ref) => 0);

/// Panel displaying live preview of the example
class PreviewPanel extends ConsumerWidget {
  final InteractiveExample? example;
  final GlobalKey repaintBoundaryKey;

  const PreviewPanel({
    super.key,
    this.example,
    required this.repaintBoundaryKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (example == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select an example to preview',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final currentFrame = ref.watch(previewFrameProvider);
    final parameterValues = ref.watch(parameterValuesProvider);
    final config = example!.getConfig();
    final maxFrames = config.timeline.durationInFrames;

    return Container(
      decoration: const BoxDecoration(
        gradient: GalleryTheme.backgroundGradient,
      ),
      child: Column(
        children: [
          // Preview area
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: repaintBoundaryKey,
                  child: SizedBox(
                    width: config.timeline.width.toDouble(),
                    height: config.timeline.height.toDouble(),
                    child: FrameProvider(
                      frame: currentFrame,
                      child: parameterValues.isEmpty
                          ? example!.buildComposition()
                          : example!.buildWithParameters(parameterValues),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Frame scrubber controls - glassmorphic bar
          GalleryTheme.glassmorphicContainer(
            borderRadius: 0,
            backgroundColor: GalleryTheme.elevatedSurface.withValues(alpha: 0.5),
            blur: 15,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Frame slider
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GalleryTheme.glassBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GalleryTheme.glassBorder),
                      ),
                      child: Text(
                        'Frame: $currentFrame',
                        style: GalleryTheme.textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: GalleryTheme.accentPink,
                          inactiveTrackColor: GalleryTheme.elevatedSurface,
                          thumbColor: GalleryTheme.accentPink,
                          overlayColor: GalleryTheme.accentPink.withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                            elevation: 3,
                          ),
                        ),
                        child: Slider(
                          value: currentFrame.toDouble(),
                          min: 0,
                          max: maxFrames.toDouble() - 1,
                          divisions: maxFrames - 1,
                          label: currentFrame.toString(),
                          onChanged: (value) {
                            ref.read(previewFrameProvider.notifier).state =
                                value.toInt();
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GalleryTheme.glassBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GalleryTheme.glassBorder),
                      ),
                      child: Text(
                        '${maxFrames - 1}',
                        style: GalleryTheme.textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Playback controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      icon: Icons.skip_previous,
                      tooltip: 'First frame',
                      onPressed: () {
                        ref.read(previewFrameProvider.notifier).state = 0;
                      },
                      ref: ref,
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Previous frame',
                      onPressed: currentFrame > 0
                          ? () {
                              ref.read(previewFrameProvider.notifier).state =
                                  currentFrame - 1;
                            }
                          : null,
                      ref: ref,
                    ),
                    const SizedBox(width: 24),
                    _buildControlButton(
                      icon: Icons.chevron_right,
                      tooltip: 'Next frame',
                      onPressed: currentFrame < maxFrames - 1
                          ? () {
                              ref.read(previewFrameProvider.notifier).state =
                                  currentFrame + 1;
                            }
                          : null,
                      ref: ref,
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      icon: Icons.skip_next,
                      tooltip: 'Last frame',
                      onPressed: () {
                        ref.read(previewFrameProvider.notifier).state =
                            maxFrames - 1;
                      },
                      ref: ref,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Video info
                Text(
                  '${config.timeline.width}x${config.timeline.height} @ ${config.timeline.fps}fps',
                  style: GalleryTheme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required WidgetRef ref,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? GalleryTheme.primaryGradient : null,
        color: onPressed == null ? GalleryTheme.elevatedSurface : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: GalleryTheme.gradientStart.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
