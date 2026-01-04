import 'dart:async';

import 'package:flutter/widgets.dart';

import 'audio_data_provider.dart';

/// Provides audio data to descendant widgets for audio-reactive animations.
///
/// [AudioReactive] uses an [InheritedWidget] pattern to make audio analysis
/// data available throughout the widget tree. Widgets can access the audio
/// data using [AudioReactive.of(context)].
///
/// Example:
/// ```dart
/// // Provide audio data
/// AudioReactive(
///   provider: myAudioProvider,
///   child: MyVideoComposition(),
/// )
///
/// // Access in a descendant widget
/// class BeatIndicator extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final audioData = AudioReactive.of(context);
///     if (audioData == null) return const SizedBox.shrink();
///
///     return TimeConsumer(
///       builder: (context, frame, _) {
///         final beatStrength = audioData.provider.getBeatStrengthAt(frame);
///         return Container(
///           width: 50 + beatStrength * 50,
///           height: 50 + beatStrength * 50,
///           decoration: BoxDecoration(
///             shape: BoxShape.circle,
///             color: Colors.red.withOpacity(beatStrength),
///           ),
///         );
///       },
///     );
///   }
/// }
/// ```
class AudioReactive extends InheritedWidget {
  /// The audio data provider.
  final AudioDataProvider provider;

  /// Whether the audio data is ready to use.
  final bool isReady;

  const AudioReactive({
    super.key,
    required this.provider,
    this.isReady = true,
    required super.child,
  });

  /// Gets the [AudioReactive] data from the given context.
  ///
  /// Returns null if no [AudioReactive] ancestor is found.
  static AudioReactive? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AudioReactive>();
  }

  /// Gets the [AudioReactive] data from the given context.
  ///
  /// Throws if no [AudioReactive] ancestor is found.
  static AudioReactive require(BuildContext context) {
    final result = of(context);
    assert(result != null, 'No AudioReactive found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AudioReactive oldWidget) {
    return provider != oldWidget.provider || isReady != oldWidget.isReady;
  }
}

/// A widget that initializes an [AudioDataProvider] and provides it to descendants.
///
/// This is a convenience widget that handles the async initialization
/// of an audio provider and shows a loading state while initializing.
///
/// Example:
/// ```dart
/// AudioReactiveBuilder(
///   provider: MockAudioDataProvider(bpm: 120),
///   loadingBuilder: (context) => const CircularProgressIndicator(),
///   builder: (context, provider) {
///     return MyVideoComposition();
///   },
/// )
/// ```
class AudioReactiveBuilder extends StatefulWidget {
  /// The audio data provider to initialize.
  final AudioDataProvider provider;

  /// Builder called when the provider is ready.
  final Widget Function(BuildContext context, AudioDataProvider provider)
      builder;

  /// Builder called while the provider is initializing.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Builder called if initialization fails.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const AudioReactiveBuilder({
    super.key,
    required this.provider,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<AudioReactiveBuilder> createState() => _AudioReactiveBuilderState();
}

class _AudioReactiveBuilderState extends State<AudioReactiveBuilder> {
  bool _isInitialized = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await widget.provider.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!) ??
          Center(child: Text('Audio initialization error: $_error'));
    }

    if (!_isInitialized) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: Text('Loading audio...'));
    }

    return AudioReactive(
      provider: widget.provider,
      isReady: true,
      child: widget.builder(context, widget.provider),
    );
  }
}

/// A mixin that provides convenient access to audio data in widgets.
///
/// Example:
/// ```dart
/// class MyWidget extends StatelessWidget with AudioReactiveMixin {
///   @override
///   Widget build(BuildContext context) {
///     return TimeConsumer(
///       builder: (context, frame, _) {
///         final beatStrength = getBeatStrength(context, frame);
///         return Container(
///           transform: Matrix4.identity()..scale(1.0 + beatStrength * 0.2),
///           child: const Text('Beat!'),
///         );
///       },
///     );
///   }
/// }
/// ```
mixin AudioReactiveMixin {
  /// Gets the audio data provider from context.
  AudioDataProvider? getAudioProvider(BuildContext context) {
    return AudioReactive.of(context)?.provider;
  }

  /// Gets the BPM from the audio provider.
  double getBpm(BuildContext context) {
    return getAudioProvider(context)?.getBpm() ?? 0;
  }

  /// Gets the amplitude at the given frame.
  double getAmplitude(BuildContext context, int frame, {int fps = 30}) {
    return getAudioProvider(context)?.getAmplitudeAt(frame, fps: fps) ?? 0;
  }

  /// Gets the beat strength at the given frame.
  double getBeatStrength(BuildContext context, int frame, {int fps = 30}) {
    return getAudioProvider(context)?.getBeatStrengthAt(frame, fps: fps) ?? 0;
  }

  /// Checks if there's a beat at the given frame.
  bool isBeat(
    BuildContext context,
    int frame, {
    int fps = 30,
    double threshold = 0.5,
  }) {
    return getAudioProvider(
          context,
        )?.isBeatAt(frame, fps: fps, threshold: threshold) ??
        false;
  }

  /// Gets frequency bands at the given frame.
  List<double> getFrequencyBands(
    BuildContext context,
    int frame, {
    int fps = 30,
    int bandCount = 8,
  }) {
    return getAudioProvider(
          context,
        )?.getFrequencyBandsAt(frame, fps: fps, bandCount: bandCount) ??
        List.filled(bandCount, 0.0);
  }

  /// Gets bass level at the given frame.
  double getBass(BuildContext context, int frame, {int fps = 30}) {
    return getAudioProvider(context)?.getBassAt(frame, fps: fps) ?? 0;
  }

  /// Gets mid level at the given frame.
  double getMid(BuildContext context, int frame, {int fps = 30}) {
    return getAudioProvider(context)?.getMidAt(frame, fps: fps) ?? 0;
  }

  /// Gets treble level at the given frame.
  double getTreble(BuildContext context, int frame, {int fps = 30}) {
    return getAudioProvider(context)?.getTrebleAt(frame, fps: fps) ?? 0;
  }
}

/// A widget that pulses based on audio beats.
///
/// Wraps a child widget and applies a scale transform that pulses
/// with the beat of the audio.
///
/// Example:
/// ```dart
/// BeatPulse(
///   minScale: 1.0,
///   maxScale: 1.2,
///   child: Text('Pulse!'),
/// )
/// ```
class BeatPulse extends StatelessWidget with AudioReactiveMixin {
  /// The child widget to pulse.
  final Widget child;

  /// Minimum scale (at no beat).
  final double minScale;

  /// Maximum scale (at full beat).
  final double maxScale;

  /// Threshold for beat detection.
  final double threshold;

  /// Current frame (if not using TimeConsumer context).
  final int? frame;

  /// FPS for beat calculation.
  final int fps;

  const BeatPulse({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 1.15,
    this.threshold = 0.3,
    this.frame,
    this.fps = 30,
  });

  @override
  Widget build(BuildContext context) {
    // If no frame provided, this needs to be inside a TimeConsumer
    final currentFrame = frame;
    if (currentFrame == null) {
      return child; // Just return child if no frame context
    }

    final beatStrength = getBeatStrength(context, currentFrame, fps: fps);
    final scale = minScale + (maxScale - minScale) * beatStrength;

    return Transform.scale(scale: scale, child: child);
  }
}

/// A widget that visualizes frequency bands as bars.
///
/// Example:
/// ```dart
/// FrequencyBars(
///   frame: currentFrame,
///   barCount: 8,
///   barWidth: 20,
///   maxHeight: 100,
///   color: Colors.green,
/// )
/// ```
class FrequencyBars extends StatelessWidget with AudioReactiveMixin {
  /// Current frame.
  final int frame;

  /// Number of frequency bars.
  final int barCount;

  /// Width of each bar.
  final double barWidth;

  /// Maximum height of bars.
  final double maxHeight;

  /// Spacing between bars.
  final double spacing;

  /// Color of the bars.
  final Color color;

  /// Optional gradient for bars.
  final Gradient? gradient;

  /// FPS for frequency calculation.
  final int fps;

  /// Whether to mirror bars (show above and below).
  final bool mirror;

  /// Border radius for bars.
  final BorderRadius? borderRadius;

  const FrequencyBars({
    super.key,
    required this.frame,
    this.barCount = 8,
    this.barWidth = 20,
    this.maxHeight = 100,
    this.spacing = 4,
    this.color = const Color(0xFF1DB954),
    this.gradient,
    this.fps = 30,
    this.mirror = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bands = getFrequencyBands(
      context,
      frame,
      fps: fps,
      bandCount: barCount,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(barCount, (i) {
        final height = bands[i] * maxHeight;

        final bar = Container(
          width: barWidth,
          height: height.clamp(2.0, maxHeight),
          decoration: BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: borderRadius ?? BorderRadius.circular(barWidth / 4),
          ),
        );

        if (!mirror) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: bar,
          );
        }

        // Mirrored version
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.flip(
                flipY: true,
                child: Container(
                  width: barWidth,
                  height: height.clamp(2.0, maxHeight) / 2,
                  decoration: BoxDecoration(
                    color:
                        gradient == null ? color.withValues(alpha: 0.5) : null,
                    gradient: gradient,
                    borderRadius:
                        borderRadius ?? BorderRadius.circular(barWidth / 4),
                  ),
                ),
              ),
              bar,
            ],
          ),
        );
      }),
    );
  }
}
