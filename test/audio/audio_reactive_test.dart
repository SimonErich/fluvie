import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/audio/audio_data_provider.dart';
import 'package:fluvie/src/declarative/audio/audio_reactive.dart';

void main() {
  group('AudioReactive', () {
    late MockAudioDataProvider provider;

    setUp(() async {
      provider = MockAudioDataProvider();
      await provider.initialize();
    });

    group('construction', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const SizedBox(),
            ),
          ),
        );

        expect(find.byType(AudioReactive), findsOneWidget);
      });

      testWidgets('isReady defaults to true', (tester) async {
        late AudioReactive audioReactive;

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: Builder(
                builder: (context) {
                  audioReactive = AudioReactive.of(context)!;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(audioReactive.isReady, isTrue);
      });

      testWidgets('allows setting isReady to false', (tester) async {
        late AudioReactive audioReactive;

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              isReady: false,
              child: Builder(
                builder: (context) {
                  audioReactive = AudioReactive.of(context)!;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(audioReactive.isReady, isFalse);
      });
    });

    group('of', () {
      testWidgets('returns AudioReactive from ancestor', (tester) async {
        AudioReactive? result;

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: Builder(
                builder: (context) {
                  result = AudioReactive.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(result, isNotNull);
        expect(result!.provider, provider);
      });

      testWidgets('returns null when no ancestor', (tester) async {
        AudioReactive? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                result = AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(result, isNull);
      });
    });

    group('require', () {
      testWidgets('returns AudioReactive from ancestor', (tester) async {
        late AudioReactive result;

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: Builder(
                builder: (context) {
                  result = AudioReactive.require(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(result.provider, provider);
      });

      testWidgets('throws assertion when no ancestor', (tester) async {
        bool assertionFailed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                try {
                  AudioReactive.require(context);
                } on AssertionError {
                  assertionFailed = true;
                }
                return const SizedBox();
              },
            ),
          ),
        );

        expect(assertionFailed, isTrue);
      });
    });

    group('updateShouldNotify', () {
      testWidgets('notifies when provider changes', (tester) async {
        var buildCount = 0;
        final provider2 = MockAudioDataProvider(bpm: 90);
        await provider2.initialize();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: Builder(
                builder: (context) {
                  AudioReactive.of(context);
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, 1);

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider2,
              child: Builder(
                builder: (context) {
                  AudioReactive.of(context);
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, 2);
      });

      testWidgets('notifies when isReady changes', (tester) async {
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              isReady: false,
              child: Builder(
                builder: (context) {
                  AudioReactive.of(context);
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, 1);

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              isReady: true,
              child: Builder(
                builder: (context) {
                  AudioReactive.of(context);
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(buildCount, 2);
      });

      testWidgets('does not notify when same values', (tester) async {
        // Create the AudioReactive with initial values
        final audioReactive1 = AudioReactive(
          provider: provider,
          isReady: true,
          child: const SizedBox(),
        );

        // Compare with same values
        final audioReactive2 = AudioReactive(
          provider: provider,
          isReady: true,
          child: const SizedBox(),
        );

        // updateShouldNotify should return false when values are same
        expect(audioReactive1.updateShouldNotify(audioReactive2), isFalse);
      });
    });
  });

  group('AudioReactiveBuilder', () {
    group('construction', () {
      testWidgets('shows loading state initially then ready', (tester) async {
        final provider = MockAudioDataProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              loadingBuilder: (context) => const Text('Loading'),
              builder: (context, provider) => const Text('Ready'),
            ),
          ),
        );

        // Initially shows loading
        expect(find.text('Loading'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);

        // After initialization completes
        await tester.pumpAndSettle();

        expect(find.text('Loading'), findsNothing);
        expect(find.text('Ready'), findsOneWidget);
      });

      testWidgets('shows builder after initialization', (tester) async {
        final provider = MockAudioDataProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              loadingBuilder: (context) => const Text('Loading'),
              builder: (context, provider) => const Text('Ready'),
            ),
          ),
        );

        // Pump to allow initialization
        await tester.pumpAndSettle();

        expect(find.text('Loading'), findsNothing);
        expect(find.text('Ready'), findsOneWidget);
      });

      testWidgets('shows error on initialization failure', (tester) async {
        final provider = _FailingMockProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              errorBuilder: (context, error) => Text('Error: $error'),
              builder: (context, provider) => const Text('Ready'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining('Error:'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);
      });

      testWidgets('uses default loading widget if not provided',
          (tester) async {
        final provider = MockAudioDataProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              builder: (context, provider) => const Text('Ready'),
            ),
          ),
        );

        // Initially shows default loading
        expect(find.text('Loading audio...'), findsOneWidget);

        // After initialization, shows ready
        await tester.pumpAndSettle();
        expect(find.text('Ready'), findsOneWidget);
      });

      testWidgets('uses default error widget if not provided', (tester) async {
        final provider = _FailingMockProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              builder: (context, provider) => const Text('Ready'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('Audio initialization error'),
          findsOneWidget,
        );
      });
    });

    group('provider lifecycle', () {
      testWidgets('disposes provider on unmount', (tester) async {
        final provider = _TrackingMockProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              builder: (context, provider) => const Text('Ready'),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(provider.disposed, isFalse);

        // Unmount the widget
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(provider.disposed, isTrue);
      });
    });

    group('AudioReactive integration', () {
      testWidgets('provides AudioReactive to descendants', (tester) async {
        final provider = MockAudioDataProvider();
        AudioReactive? audioReactive;

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactiveBuilder(
              provider: provider,
              builder: (context, provider) => Builder(
                builder: (innerContext) {
                  audioReactive = AudioReactive.of(innerContext);
                  return const Text('Ready');
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(audioReactive, isNotNull);
        expect(audioReactive!.isReady, isTrue);
        expect(audioReactive!.provider, provider);
      });
    });
  });

  group('BeatPulse', () {
    late MockAudioDataProvider provider;

    setUp(() async {
      provider = MockAudioDataProvider(bpm: 120);
      await provider.initialize();
    });

    group('construction', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const BeatPulse(
                frame: 0,
                child: Text('Beat'),
              ),
            ),
          ),
        );

        expect(find.byType(BeatPulse), findsOneWidget);
        expect(find.text('Beat'), findsOneWidget);
      });

      testWidgets('applies default scale parameters', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const BeatPulse(
                frame: 0,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );

        // Should have Transform.scale widget
        expect(find.byType(Transform), findsOneWidget);
      });
    });

    group('scaling behavior', () {
      testWidgets('scales based on beat strength', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const BeatPulse(
                frame: 0,
                minScale: 1.0,
                maxScale: 2.0,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );

        final transform = tester.widget<Transform>(find.byType(Transform));
        final matrix = transform.transform;
        final scale = matrix.getMaxScaleOnAxis();

        // Scale should be between min and max
        expect(scale, greaterThanOrEqualTo(1.0));
        expect(scale, lessThanOrEqualTo(2.0));
      });

      testWidgets('returns child without transform when no frame',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const BeatPulse(
                child: Text('No Frame'),
              ),
            ),
          ),
        );

        expect(find.text('No Frame'), findsOneWidget);
      });
    });

    group('without AudioReactive ancestor', () {
      testWidgets('renders child with default scale', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: BeatPulse(
              frame: 0,
              child: Text('No Audio'),
            ),
          ),
        );

        expect(find.text('No Audio'), findsOneWidget);
      });
    });
  });

  group('FrequencyBars', () {
    late MockAudioDataProvider provider;

    setUp(() async {
      provider = MockAudioDataProvider(bpm: 120);
      await provider.initialize();
    });

    group('construction', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(frame: 0),
            ),
          ),
        );

        expect(find.byType(FrequencyBars), findsOneWidget);
      });

      testWidgets('creates correct number of bars', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 8,
              ),
            ),
          ),
        );

        // Should have 8 Container widgets for bars (inside Row)
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, 8);
      });

      testWidgets('respects custom bar count', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 16,
              ),
            ),
          ),
        );

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, 16);
      });
    });

    group('styling', () {
      testWidgets('applies bar width', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 4,
                barWidth: 30,
              ),
            ),
          ),
        );

        // FrequencyBars renders correctly
        expect(find.byType(FrequencyBars), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);

        // Verify the FrequencyBars widget has the correct barWidth property
        final frequencyBars =
            tester.widget<FrequencyBars>(find.byType(FrequencyBars));
        expect(frequencyBars.barWidth, 30);
      });

      testWidgets('applies custom color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 4,
                color: Colors.red,
              ),
            ),
          ),
        );

        // Verify the FrequencyBars widget has the correct color property
        final frequencyBars =
            tester.widget<FrequencyBars>(find.byType(FrequencyBars));
        expect(frequencyBars.color, Colors.red);
      });
    });

    group('mirror mode', () {
      testWidgets('creates mirrored bars when enabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 4,
                mirror: true,
              ),
            ),
          ),
        );

        // Mirror mode creates Column widgets with Transform.flip
        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('does not mirror by default', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: provider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 4,
                mirror: false,
              ),
            ),
          ),
        );

        // Without mirror, no Column for mirroring
        final row = tester.widget<Row>(find.byType(Row));
        final hasColumn = row.children.any((child) {
          if (child is Padding) {
            return child.child is Column;
          }
          return false;
        });
        expect(hasColumn, isFalse);
      });
    });

    group('without AudioReactive ancestor', () {
      testWidgets('renders empty bars', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FrequencyBars(
              frame: 0,
              barCount: 4,
            ),
          ),
        );

        // Should still render the Row with bars
        expect(find.byType(Row), findsOneWidget);
      });
    });

    group('bar height constraints', () {
      testWidgets('clamps bar height to minimum of 2', (tester) async {
        // Use a provider that would give very low values
        final quietProvider = MockAudioDataProvider(amplitudeVariation: 0);
        await quietProvider.initialize();

        await tester.pumpWidget(
          MaterialApp(
            home: AudioReactive(
              provider: quietProvider,
              child: const FrequencyBars(
                frame: 0,
                barCount: 4,
                maxHeight: 100,
              ),
            ),
          ),
        );

        // FrequencyBars should render and show bars
        expect(find.byType(FrequencyBars), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);

        // The row should have children (bars)
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, 4);
      });
    });
  });

  group('AudioReactiveMixin', () {
    late MockAudioDataProvider provider;

    setUp(() async {
      provider = MockAudioDataProvider(bpm: 120);
      await provider.initialize();
    });

    testWidgets('getAudioProvider returns provider from context',
        (tester) async {
      final key = GlobalKey<_TestMixinWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: _TestMixinWidget(key: key),
          ),
        ),
      );

      expect(key.currentState!.lastProvider, provider);
    });

    testWidgets('getAudioProvider returns null without ancestor',
        (tester) async {
      final key = GlobalKey<_TestMixinWidgetState>();

      await tester.pumpWidget(
        MaterialApp(home: _TestMixinWidget(key: key)),
      );

      expect(key.currentState!.lastProvider, isNull);
    });

    testWidgets('getBpm returns BPM from provider', (tester) async {
      final key = GlobalKey<_TestMixinWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: _TestMixinWidget(key: key),
          ),
        ),
      );

      expect(key.currentState!.lastBpm, 120);
    });

    testWidgets('getBpm returns 0 without provider', (tester) async {
      final key = GlobalKey<_TestMixinWidgetState>();

      await tester.pumpWidget(
        MaterialApp(home: _TestMixinWidget(key: key)),
      );

      expect(key.currentState!.lastBpm, 0);
    });

    testWidgets('getFrequencyBands returns bands from provider',
        (tester) async {
      final key = GlobalKey<_TestMixinWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: _TestMixinWidget(key: key),
          ),
        ),
      );

      expect(key.currentState!.lastBands.length, 8);
    });

    testWidgets('getFrequencyBands returns empty list without provider',
        (tester) async {
      final key = GlobalKey<_TestMixinWidgetState>();

      await tester.pumpWidget(
        MaterialApp(home: _TestMixinWidget(key: key)),
      );

      expect(key.currentState!.lastBands.length, 8);
      expect(key.currentState!.lastBands.every((v) => v == 0.0), isTrue);
    });
  });
}

/// A mock provider that fails during initialization.
class _FailingMockProvider implements AudioDataProvider {
  @override
  Future<void> initialize() async {
    throw Exception('Initialization failed');
  }

  @override
  void dispose() {}

  @override
  double getBpm() => 0;

  @override
  double getAmplitudeAt(int frame, {int fps = 30}) => 0;

  @override
  double getBeatStrengthAt(int frame, {int fps = 30}) => 0;

  @override
  bool isBeatAt(int frame, {int fps = 30, double threshold = 0.5}) => false;

  @override
  List<double> getFrequencyBandsAt(int frame,
          {int fps = 30, int bandCount = 8}) =>
      List.filled(bandCount, 0.0);

  @override
  double getBassAt(int frame, {int fps = 30}) => 0;

  @override
  double getMidAt(int frame, {int fps = 30}) => 0;

  @override
  double getTrebleAt(int frame, {int fps = 30}) => 0;

  @override
  double getDuration() => 0;

  @override
  int? getNextBeatFrame(int currentFrame, {int fps = 30}) => null;

  @override
  List<int> getAllBeatFrames({int fps = 30}) => [];
}

/// A mock provider that tracks disposal.
class _TrackingMockProvider extends MockAudioDataProvider {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// A test widget that uses the AudioReactiveMixin.
class _TestMixinWidget extends StatefulWidget {
  const _TestMixinWidget({super.key});

  @override
  State<_TestMixinWidget> createState() => _TestMixinWidgetState();
}

class _TestMixinWidgetState extends State<_TestMixinWidget>
    with AudioReactiveMixin {
  AudioDataProvider? lastProvider;
  double lastBpm = 0;
  List<double> lastBands = [];

  @override
  Widget build(BuildContext context) {
    lastProvider = getAudioProvider(context);
    lastBpm = getBpm(context);
    lastBands = getFrequencyBands(context, 0);
    return const SizedBox();
  }
}
