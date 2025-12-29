/// Audio integration for video composition.
///
/// This library provides audio analysis and audio-reactive animation
/// capabilities for the declarative video composition API.
///
/// ## Audio Data Provider
///
/// The [AudioDataProvider] interface defines methods for accessing
/// audio analysis data:
///
/// ```dart
/// final provider = MockAudioDataProvider(bpm: 120);
/// await provider.initialize();
///
/// // Get BPM
/// final bpm = provider.getBpm();
///
/// // Get beat strength at a specific frame
/// final beat = provider.getBeatStrengthAt(frame, fps: 30);
///
/// // Get frequency bands
/// final bands = provider.getFrequencyBandsAt(frame, fps: 30);
/// ```
///
/// ## Audio Reactive Widgets
///
/// Use [AudioReactive] to provide audio data to descendant widgets:
///
/// ```dart
/// AudioReactive(
///   provider: myProvider,
///   child: Video(
///     scenes: [
///       Scene(
///         children: [
///           TimeConsumer(
///             builder: (context, frame, _) {
///               final audio = AudioReactive.of(context);
///               final beat = audio?.provider.getBeatStrengthAt(frame) ?? 0;
///               return BeatIndicator(strength: beat);
///             },
///           ),
///         ],
///       ),
///     ],
///   ),
/// )
/// ```
///
/// ## Convenience Widgets
///
/// - [BeatPulse] - Scales a widget based on beat strength
/// - [FrequencyBars] - Visualizes frequency bands as bars
///
/// ```dart
/// BeatPulse(
///   frame: currentFrame,
///   minScale: 1.0,
///   maxScale: 1.3,
///   child: Text('Pulse with the beat!'),
/// )
/// ```
///
/// ## BPM Detection
///
/// Use [BpmDetector] to analyze audio files for tempo:
///
/// ```dart
/// final detector = BpmDetector();
/// final bpm = detector.detect(samples, sampleRate: 44100);
/// ```
///
/// ## Frequency Analysis
///
/// Use [FrequencyAnalyzer] for FFT-based frequency analysis:
///
/// ```dart
/// final analyzer = FrequencyAnalyzer(bandCount: 8);
/// final bands = analyzer.analyze(samples, sampleRate: 44100);
/// print('Bass: ${bands.bass}, Mid: ${bands.mid}, Treble: ${bands.treble}');
/// ```
library;

export 'audio_data_provider.dart';
export 'audio_reactive.dart';
export 'bpm_detector.dart';
export 'frequency_analyzer.dart';
