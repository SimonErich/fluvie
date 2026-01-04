import 'dart:math' as math;
import 'dart:typed_data';

/// Analyzes frequency content of audio data.
///
/// This class provides FFT-based frequency analysis for audio,
/// returning frequency band data that can be used for audio-reactive
/// visualizations and animations.
///
/// Example:
/// ```dart
/// final analyzer = FrequencyAnalyzer();
/// final samples = await loadAudioSamples('audio.mp3');
/// final bands = analyzer.analyze(samples, sampleRate: 44100);
/// print('Bass level: ${bands.bass}');
/// ```
class FrequencyAnalyzer {
  /// Number of frequency bands to return.
  final int bandCount;

  /// FFT window size (must be power of 2).
  final int fftSize;

  /// Smoothing factor for frequency data (0.0 = no smoothing, 1.0 = max smoothing).
  final double smoothing;

  List<double>? _previousBands;

  FrequencyAnalyzer({
    this.bandCount = 8,
    this.fftSize = 1024,
    this.smoothing = 0.3,
  })  : assert(bandCount > 0),
        assert(
          fftSize > 0 && (fftSize & (fftSize - 1)) == 0,
          'fftSize must be power of 2',
        );

  /// Analyzes a window of audio samples and returns frequency band data.
  ///
  /// [samples] is a list of audio sample values (-1.0 to 1.0).
  /// [sampleRate] is the audio sample rate (e.g., 44100).
  ///
  /// Returns [FrequencyBands] containing normalized frequency data.
  FrequencyBands analyze(Float64List samples, {required int sampleRate}) {
    if (samples.length < fftSize) {
      // Pad with zeros if not enough samples
      final padded = Float64List(fftSize);
      for (var i = 0; i < samples.length; i++) {
        padded[i] = samples[i];
      }
      return _analyzeWindow(padded, sampleRate);
    }

    return _analyzeWindow(samples.sublist(0, fftSize), sampleRate);
  }

  /// Analyzes audio at a specific time position.
  ///
  /// [allSamples] is the complete audio sample data.
  /// [timeSeconds] is the time position in seconds.
  /// [sampleRate] is the audio sample rate.
  FrequencyBands analyzeAt(
    Float64List allSamples,
    double timeSeconds, {
    required int sampleRate,
  }) {
    final startSample = (timeSeconds * sampleRate).round();
    if (startSample < 0 || startSample >= allSamples.length) {
      return FrequencyBands.empty(bandCount);
    }

    final endSample = math.min(startSample + fftSize, allSamples.length);
    final window = Float64List(fftSize);

    for (var i = 0; i < fftSize && startSample + i < endSample; i++) {
      window[i] = allSamples[startSample + i];
    }

    return _analyzeWindow(window, sampleRate);
  }

  /// Analyzes audio at a specific frame.
  ///
  /// [allSamples] is the complete audio sample data.
  /// [frame] is the video frame number.
  /// [fps] is the video frame rate.
  /// [sampleRate] is the audio sample rate.
  FrequencyBands analyzeAtFrame(
    Float64List allSamples,
    int frame, {
    required int fps,
    required int sampleRate,
  }) {
    final timeSeconds = frame / fps;
    return analyzeAt(allSamples, timeSeconds, sampleRate: sampleRate);
  }

  FrequencyBands _analyzeWindow(Float64List samples, int sampleRate) {
    // Apply Hann window
    final windowed = _applyHannWindow(samples);

    // Compute FFT magnitude
    final magnitudes = _computeFFTMagnitudes(windowed);

    // Group into frequency bands
    final bands = _groupIntoBands(magnitudes, sampleRate);

    // Apply smoothing
    if (_previousBands != null && smoothing > 0) {
      for (var i = 0; i < bands.length; i++) {
        bands[i] = _previousBands![i] * smoothing + bands[i] * (1 - smoothing);
      }
    }
    _previousBands = List.from(bands);

    return FrequencyBands(bands);
  }

  Float64List _applyHannWindow(Float64List samples) {
    final windowed = Float64List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      final window =
          0.5 * (1 - math.cos(2 * math.pi * i / (samples.length - 1)));
      windowed[i] = samples[i] * window;
    }
    return windowed;
  }

  List<double> _computeFFTMagnitudes(Float64List samples) {
    // Simple DFT implementation (for accuracy, not performance)
    // In production, use a proper FFT library
    final n = samples.length;
    final magnitudes = List<double>.filled(n ~/ 2, 0);

    for (var k = 0; k < n ~/ 2; k++) {
      var real = 0.0;
      var imag = 0.0;

      for (var t = 0; t < n; t++) {
        final angle = 2 * math.pi * k * t / n;
        real += samples[t] * math.cos(angle);
        imag -= samples[t] * math.sin(angle);
      }

      magnitudes[k] = math.sqrt(real * real + imag * imag) / n;
    }

    return magnitudes;
  }

  List<double> _groupIntoBands(List<double> magnitudes, int sampleRate) {
    final bands = List<double>.filled(bandCount, 0);
    final nyquist = sampleRate / 2;
    final binWidth = nyquist / magnitudes.length;

    // Logarithmic frequency bands
    final minFreq = 20.0;
    final maxFreq = nyquist.toDouble();
    final logMin = math.log(minFreq);
    final logMax = math.log(maxFreq);
    final logStep = (logMax - logMin) / bandCount;

    for (var i = 0; i < bandCount; i++) {
      final lowFreq = math.exp(logMin + i * logStep);
      final highFreq = math.exp(logMin + (i + 1) * logStep);

      final lowBin = (lowFreq / binWidth).floor().clamp(
            0,
            magnitudes.length - 1,
          );
      final highBin = (highFreq / binWidth).ceil().clamp(
            0,
            magnitudes.length - 1,
          );

      if (highBin > lowBin) {
        var sum = 0.0;
        for (var bin = lowBin; bin < highBin; bin++) {
          sum += magnitudes[bin];
        }
        bands[i] = sum / (highBin - lowBin);
      }
    }

    // Normalize to 0-1 range
    final maxMagnitude = bands.reduce(math.max);
    if (maxMagnitude > 0) {
      for (var i = 0; i < bands.length; i++) {
        bands[i] = (bands[i] / maxMagnitude).clamp(0.0, 1.0);
      }
    }

    return bands;
  }

  /// Resets the smoothing state.
  void reset() {
    _previousBands = null;
  }
}

/// Contains frequency band data from audio analysis.
class FrequencyBands {
  /// Raw frequency band values (0.0 to 1.0).
  final List<double> values;

  const FrequencyBands(this.values);

  /// Creates empty frequency bands.
  factory FrequencyBands.empty(int count) {
    return FrequencyBands(List.filled(count, 0.0));
  }

  /// Number of frequency bands.
  int get length => values.length;

  /// Gets a specific band value.
  double operator [](int index) => values[index];

  /// Bass level (lowest third of bands).
  double get bass {
    if (values.isEmpty) return 0.0;
    final count = (values.length / 3).ceil();
    return values.take(count).reduce((a, b) => a + b) / count;
  }

  /// Mid level (middle third of bands).
  double get mid {
    if (values.isEmpty) return 0.0;
    final third = (values.length / 3).floor();
    final midBands = values.skip(third).take(third).toList();
    if (midBands.isEmpty) return 0.0;
    return midBands.reduce((a, b) => a + b) / midBands.length;
  }

  /// Treble level (highest third of bands).
  double get treble {
    if (values.isEmpty) return 0.0;
    final third = (values.length / 3).floor();
    final trebleBands = values.skip(third * 2).toList();
    if (trebleBands.isEmpty) return 0.0;
    return trebleBands.reduce((a, b) => a + b) / trebleBands.length;
  }

  /// Overall amplitude (average of all bands).
  double get amplitude {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Peak level (maximum band value).
  double get peak {
    if (values.isEmpty) return 0.0;
    return values.reduce(math.max);
  }

  @override
  String toString() => 'FrequencyBands($values)';
}
