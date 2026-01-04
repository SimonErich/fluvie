/// Abstract interface for providing audio analysis data.
///
/// [AudioDataProvider] defines the contract for audio analysis implementations.
/// It provides methods for accessing BPM, frequency data, beat detection,
/// and amplitude information that can be used for audio-reactive animations.
///
/// Implementations might analyze audio files, receive real-time audio input,
/// or provide mock data for testing/preview purposes.
///
/// Example implementation:
/// ```dart
/// class FileAudioDataProvider implements AudioDataProvider {
///   final String audioPath;
///   late final List<double> _amplitudeData;
///   late final double _bpm;
///
///   FileAudioDataProvider(this.audioPath);
///
///   @override
///   Future<void> initialize() async {
///     // Analyze audio file...
///   }
///
///   @override
///   double getBpm() => _bpm;
///
///   @override
///   double getAmplitudeAt(int frame, {int fps = 30}) {
///     final index = (frame / fps * _amplitudeData.length).floor();
///     return _amplitudeData[index.clamp(0, _amplitudeData.length - 1)];
///   }
/// }
/// ```
abstract class AudioDataProvider {
  /// Initializes the audio data provider.
  ///
  /// This should be called before accessing any audio data.
  /// Implementations may use this to load and analyze audio files.
  Future<void> initialize();

  /// Disposes of any resources held by the provider.
  void dispose();

  /// Returns the detected BPM (beats per minute) of the audio.
  ///
  /// Returns 0 if BPM detection failed or audio has no clear tempo.
  double getBpm();

  /// Returns the amplitude (volume level) at the given frame.
  ///
  /// [frame] is the video frame number.
  /// [fps] is the video frame rate (default 30).
  ///
  /// Returns a value between 0.0 (silence) and 1.0 (maximum volume).
  double getAmplitudeAt(int frame, {int fps = 30});

  /// Returns the beat strength at the given frame.
  ///
  /// This indicates how strong a beat is at the given moment.
  /// Useful for triggering effects on strong beats.
  ///
  /// [frame] is the video frame number.
  /// [fps] is the video frame rate (default 30).
  ///
  /// Returns a value between 0.0 (no beat) and 1.0 (strong beat).
  double getBeatStrengthAt(int frame, {int fps = 30});

  /// Returns whether there is a beat at the given frame.
  ///
  /// [frame] is the video frame number.
  /// [fps] is the video frame rate (default 30).
  /// [threshold] is the minimum beat strength to consider as a beat.
  bool isBeatAt(int frame, {int fps = 30, double threshold = 0.5});

  /// Returns frequency band data at the given frame.
  ///
  /// [frame] is the video frame number.
  /// [fps] is the video frame rate (default 30).
  /// [bandCount] is the number of frequency bands to return (default 8).
  ///
  /// Returns a list of values between 0.0 and 1.0, one for each band.
  /// Lower indices represent lower frequencies (bass), higher indices
  /// represent higher frequencies (treble).
  List<double> getFrequencyBandsAt(
    int frame, {
    int fps = 30,
    int bandCount = 8,
  });

  /// Returns the bass level (low frequency) at the given frame.
  ///
  /// Convenience method that returns the average of the lower frequency bands.
  double getBassAt(int frame, {int fps = 30});

  /// Returns the mid level (mid frequency) at the given frame.
  ///
  /// Convenience method that returns the average of the middle frequency bands.
  double getMidAt(int frame, {int fps = 30});

  /// Returns the treble level (high frequency) at the given frame.
  ///
  /// Convenience method that returns the average of the higher frequency bands.
  double getTrebleAt(int frame, {int fps = 30});

  /// Returns the total duration of the audio in seconds.
  double getDuration();

  /// Returns the frame number for the next beat after the given frame.
  ///
  /// Returns null if there are no more beats.
  int? getNextBeatFrame(int currentFrame, {int fps = 30});

  /// Returns a list of all beat frame numbers.
  List<int> getAllBeatFrames({int fps = 30});
}

/// A mock audio data provider for testing and preview purposes.
///
/// Generates synthetic audio data based on BPM and random seeds
/// for consistent, reproducible results.
class MockAudioDataProvider implements AudioDataProvider {
  /// The simulated BPM.
  final double bpm;

  /// Duration of the simulated audio in seconds.
  final double duration;

  /// Seed for random number generation.
  final int seed;

  /// Amplitude variation (0.0-1.0).
  final double amplitudeVariation;

  late final List<double> _amplitudeData;
  late final List<double> _beatStrengths;

  MockAudioDataProvider({
    this.bpm = 120,
    this.duration = 60,
    this.seed = 42,
    this.amplitudeVariation = 0.3,
  });

  @override
  Future<void> initialize() async {
    _generateData();
  }

  void _generateData() {
    final random = _SeededRandom(seed);
    final sampleCount = (duration * 100).round(); // 100 samples per second

    // Generate amplitude data
    _amplitudeData = List.generate(sampleCount, (i) {
      final base = 0.5 + random.nextDouble() * amplitudeVariation;
      return base.clamp(0.0, 1.0);
    });

    // Generate beat data based on BPM
    final beatsPerSecond = bpm / 60;
    final samplesPerBeat = 100 / beatsPerSecond;
    final beatCount = (sampleCount / samplesPerBeat).floor();

    _beatStrengths = List.filled(sampleCount, 0.0);

    for (var i = 0; i < beatCount; i++) {
      final beatSample = (i * samplesPerBeat).round();
      if (beatSample < sampleCount) {
        // Strong beat on 1 and 3, medium on 2 and 4
        final strength = (i % 4 == 0)
            ? 1.0
            : (i % 2 == 0)
                ? 0.7
                : 0.5;
        _beatStrengths[beatSample] = strength;

        // Add some decay after the beat
        for (var j = 1; j < 10 && beatSample + j < sampleCount; j++) {
          _beatStrengths[beatSample + j] = strength * (1 - j / 10);
        }
      }
    }
  }

  int _frameToSample(int frame, int fps) {
    final timeSeconds = frame / fps;
    return (timeSeconds * 100).round().clamp(0, _amplitudeData.length - 1);
  }

  @override
  void dispose() {}

  @override
  double getBpm() => bpm;

  @override
  double getAmplitudeAt(int frame, {int fps = 30}) {
    final sample = _frameToSample(frame, fps);
    return _amplitudeData[sample];
  }

  @override
  double getBeatStrengthAt(int frame, {int fps = 30}) {
    final sample = _frameToSample(frame, fps);
    return _beatStrengths[sample];
  }

  @override
  bool isBeatAt(int frame, {int fps = 30, double threshold = 0.5}) {
    return getBeatStrengthAt(frame, fps: fps) >= threshold;
  }

  @override
  List<double> getFrequencyBandsAt(
    int frame, {
    int fps = 30,
    int bandCount = 8,
  }) {
    final random = _SeededRandom(seed + frame);
    final amplitude = getAmplitudeAt(frame, fps: fps);
    final beatStrength = getBeatStrengthAt(frame, fps: fps);

    return List.generate(bandCount, (i) {
      // Bass responds more to beats
      final beatInfluence = i < bandCount / 3 ? beatStrength * 0.5 : 0.0;
      final base = amplitude * (0.5 + random.nextDouble() * 0.5);
      return (base + beatInfluence).clamp(0.0, 1.0);
    });
  }

  @override
  double getBassAt(int frame, {int fps = 30}) {
    final bands = getFrequencyBandsAt(frame, fps: fps);
    final bassCount = (bands.length / 3).floor();
    return bands.take(bassCount).reduce((a, b) => a + b) / bassCount;
  }

  @override
  double getMidAt(int frame, {int fps = 30}) {
    final bands = getFrequencyBandsAt(frame, fps: fps);
    final third = (bands.length / 3).floor();
    final midBands = bands.skip(third).take(third).toList();
    return midBands.reduce((a, b) => a + b) / midBands.length;
  }

  @override
  double getTrebleAt(int frame, {int fps = 30}) {
    final bands = getFrequencyBandsAt(frame, fps: fps);
    final third = (bands.length / 3).floor();
    final trebleBands = bands.skip(third * 2).toList();
    return trebleBands.reduce((a, b) => a + b) / trebleBands.length;
  }

  @override
  double getDuration() => duration;

  @override
  int? getNextBeatFrame(int currentFrame, {int fps = 30}) {
    final allBeats = getAllBeatFrames(fps: fps);
    for (final beat in allBeats) {
      if (beat > currentFrame) return beat;
    }
    return null;
  }

  @override
  List<int> getAllBeatFrames({int fps = 30}) {
    final beatsPerSecond = bpm / 60;
    final framesPerBeat = fps / beatsPerSecond;
    final totalFrames = (duration * fps).round();
    final beatCount = (totalFrames / framesPerBeat).floor();

    return List.generate(beatCount, (i) => (i * framesPerBeat).round());
  }
}

/// Simple seeded random number generator for reproducible results.
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}
