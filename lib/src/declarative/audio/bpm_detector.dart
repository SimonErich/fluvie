import 'dart:math' as math;
import 'dart:typed_data';

/// Detects the BPM (beats per minute) of audio data.
///
/// This class provides algorithms for detecting the tempo of audio,
/// which can be used for audio-reactive animations and beat-synced effects.
///
/// Example:
/// ```dart
/// final detector = BpmDetector();
/// final samples = await loadAudioSamples('audio.mp3');
/// final bpm = detector.detect(samples, sampleRate: 44100);
/// print('Detected BPM: $bpm');
/// ```
class BpmDetector {
  /// Minimum BPM to detect.
  final double minBpm;

  /// Maximum BPM to detect.
  final double maxBpm;

  /// Number of intervals to average for more accurate detection.
  final int intervalCount;

  const BpmDetector({
    this.minBpm = 60,
    this.maxBpm = 180,
    this.intervalCount = 20,
  });

  /// Detects BPM from audio samples.
  ///
  /// [samples] is a list of audio sample values (-1.0 to 1.0).
  /// [sampleRate] is the audio sample rate (e.g., 44100 for CD quality).
  ///
  /// Returns the detected BPM, or 0 if detection failed.
  double detect(Float64List samples, {required int sampleRate}) {
    if (samples.isEmpty) return 0;

    // Step 1: Calculate energy for each window
    final energyData = _calculateEnergy(samples, sampleRate);
    if (energyData.isEmpty) return 0;

    // Step 2: Detect peaks in energy data
    final peaks = _detectPeaks(energyData);
    if (peaks.length < 2) return 0;

    // Step 3: Calculate intervals between peaks
    final intervals = _calculateIntervals(peaks);
    if (intervals.isEmpty) return 0;

    // Step 4: Find most common interval (tempo)
    final bpm = _findDominantBpm(intervals, sampleRate);

    return bpm.clamp(minBpm, maxBpm);
  }

  /// Detects BPM from pre-computed beat timestamps.
  ///
  /// [beatTimestamps] is a list of beat times in seconds.
  ///
  /// Returns the detected BPM, or 0 if detection failed.
  double detectFromTimestamps(List<double> beatTimestamps) {
    if (beatTimestamps.length < 2) return 0;

    final intervals = <double>[];
    for (var i = 1; i < beatTimestamps.length; i++) {
      intervals.add(beatTimestamps[i] - beatTimestamps[i - 1]);
    }

    if (intervals.isEmpty) return 0;

    // Average interval in seconds
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

    // Convert to BPM
    if (avgInterval <= 0) return 0;
    final bpm = 60 / avgInterval;

    return bpm.clamp(minBpm, maxBpm);
  }

  List<double> _calculateEnergy(Float64List samples, int sampleRate) {
    // Window size for energy calculation (around 10ms)
    final windowSize = (sampleRate * 0.01).round();
    final hopSize = windowSize ~/ 2;
    final energyCount = (samples.length - windowSize) ~/ hopSize;

    if (energyCount <= 0) return [];

    final energy = List<double>.filled(energyCount, 0);

    for (var i = 0; i < energyCount; i++) {
      final start = i * hopSize;
      var sum = 0.0;
      for (var j = 0; j < windowSize && start + j < samples.length; j++) {
        sum += samples[start + j] * samples[start + j];
      }
      energy[i] = sum / windowSize;
    }

    return energy;
  }

  List<int> _detectPeaks(List<double> energy) {
    if (energy.length < 3) return [];

    // Calculate moving average and threshold
    final windowSize = math.min(50, energy.length ~/ 4);
    final peaks = <int>[];

    for (var i = windowSize; i < energy.length - windowSize; i++) {
      // Calculate local average
      var localSum = 0.0;
      for (var j = i - windowSize; j < i + windowSize; j++) {
        localSum += energy[j];
      }
      final localAvg = localSum / (windowSize * 2);

      // Check if this is a peak above average
      final threshold = localAvg * 1.3;
      if (energy[i] > threshold) {
        // Check if this is a local maximum
        if (energy[i] > energy[i - 1] && energy[i] >= energy[i + 1]) {
          // Don't add if too close to previous peak
          if (peaks.isEmpty || i - peaks.last > windowSize ~/ 2) {
            peaks.add(i);
          }
        }
      }
    }

    return peaks;
  }

  List<int> _calculateIntervals(List<int> peaks) {
    final intervals = <int>[];
    for (var i = 1; i < peaks.length && intervals.length < intervalCount; i++) {
      intervals.add(peaks[i] - peaks[i - 1]);
    }
    return intervals;
  }

  double _findDominantBpm(List<int> intervals, int sampleRate) {
    if (intervals.isEmpty) return 0;

    // Convert intervals to BPM values
    final hopSize = (sampleRate * 0.01 / 2).round();
    final bpmValues = intervals
        .map((interval) {
          final seconds = interval * hopSize / sampleRate;
          return seconds > 0 ? 60 / seconds : 0.0;
        })
        .where((bpm) => bpm >= minBpm && bpm <= maxBpm)
        .toList();

    if (bpmValues.isEmpty) return 0;

    // Find median BPM for robustness
    bpmValues.sort();
    final median = bpmValues[bpmValues.length ~/ 2];

    // Average values close to median
    final closeValues = bpmValues
        .where((bpm) => (bpm - median).abs() < 10)
        .toList();
    if (closeValues.isEmpty) return median;

    return closeValues.reduce((a, b) => a + b) / closeValues.length;
  }
}

/// Result of BPM detection with confidence information.
class BpmDetectionResult {
  /// The detected BPM.
  final double bpm;

  /// Confidence level (0.0 to 1.0).
  final double confidence;

  /// Alternative BPM values that were considered.
  final List<double> alternatives;

  const BpmDetectionResult({
    required this.bpm,
    required this.confidence,
    this.alternatives = const [],
  });

  /// Whether the detection was successful with reasonable confidence.
  bool get isReliable => confidence >= 0.6;

  @override
  String toString() => 'BpmDetectionResult(bpm: $bpm, confidence: $confidence)';
}
