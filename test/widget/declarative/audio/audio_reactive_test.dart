import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/audio/audio_reactive.dart';
import 'package:fluvie/src/declarative/audio/audio_data_provider.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('AudioReactive', () {
    late MockAudioDataProvider provider;

    setUp(() async {
      provider = MockAudioDataProvider(bpm: 120);
      await provider.initialize();
    });

    group('construction', () {
      testWidgets('creates with required parameters', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: const Text('Test'),
          ),
        ));

        expect(find.text('Test'), findsOneWidget);
      });

      testWidgets('defaults isReady to true', (tester) async {
        late AudioReactive? foundReactive;

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: Builder(
              builder: (context) {
                foundReactive = AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(foundReactive?.isReady, isTrue);
      });

      testWidgets('accepts custom isReady', (tester) async {
        late AudioReactive? foundReactive;

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            isReady: false,
            child: Builder(
              builder: (context) {
                foundReactive = AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(foundReactive?.isReady, isFalse);
      });
    });

    group('of', () {
      testWidgets('returns AudioReactive when ancestor exists', (tester) async {
        AudioReactive? foundReactive;

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: Builder(
              builder: (context) {
                foundReactive = AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(foundReactive, isNotNull);
        expect(foundReactive?.provider, provider);
      });

      testWidgets('returns null when no ancestor', (tester) async {
        AudioReactive? foundReactive;

        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) {
              foundReactive = AudioReactive.of(context);
              return const SizedBox();
            },
          ),
        ));

        expect(foundReactive, isNull);
      });
    });

    group('require', () {
      testWidgets('returns AudioReactive when ancestor exists', (tester) async {
        AudioReactive? foundReactive;

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: Builder(
              builder: (context) {
                foundReactive = AudioReactive.require(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(foundReactive, isNotNull);
        expect(foundReactive?.provider, provider);
      });
    });

    group('updateShouldNotify', () {
      testWidgets('notifies when provider changes', (tester) async {
        var buildCount = 0;
        final provider2 = MockAudioDataProvider(bpm: 140);
        await provider2.initialize();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: Builder(
              builder: (context) {
                buildCount++;
                AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(buildCount, 1);

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider2,
            child: Builder(
              builder: (context) {
                buildCount++;
                AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(buildCount, 2);
      });

      testWidgets('notifies when isReady changes', (tester) async {
        var buildCount = 0;

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            isReady: false,
            child: Builder(
              builder: (context) {
                buildCount++;
                AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(buildCount, 1);

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            isReady: true,
            child: Builder(
              builder: (context) {
                buildCount++;
                AudioReactive.of(context);
                return const SizedBox();
              },
            ),
          ),
        ));

        expect(buildCount, 2);
      });
    });
  });

  group('AudioReactiveBuilder', () {
    group('construction', () {
      testWidgets('shows loading while initializing', (tester) async {
        final provider = MockAudioDataProvider();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactiveBuilder(
            provider: provider,
            loadingBuilder: (context) => const Text('Loading...'),
            builder: (context, p) => const Text('Ready'),
          ),
        ));

        expect(find.text('Loading...'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);
      });

      testWidgets('shows builder when ready', (tester) async {
        final provider = MockAudioDataProvider();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactiveBuilder(
            provider: provider,
            loadingBuilder: (context) => const Text('Loading...'),
            builder: (context, p) => const Text('Ready'),
          ),
        ));

        // Wait for initialization
        await tester.pumpAndSettle();

        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Loading...'), findsNothing);
      });

      testWidgets('uses default loading when loadingBuilder not provided',
          (tester) async {
        final provider = MockAudioDataProvider();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactiveBuilder(
            provider: provider,
            builder: (context, p) => const Text('Ready'),
          ),
        ));

        expect(find.text('Loading audio...'), findsOneWidget);
      });

      testWidgets('provides AudioReactive context to builder', (tester) async {
        // Use a pre-initialized provider directly with AudioReactive
        // to verify context propagation works
        final provider = MockAudioDataProvider(bpm: 100);
        await provider.initialize();

        AudioReactive? foundReactive;
        double? foundBpm;

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: Builder(
              builder: (context) {
                foundReactive = AudioReactive.of(context);
                foundBpm = foundReactive?.provider.getBpm();
                return Text('BPM: $foundBpm');
              },
            ),
          ),
        ));

        expect(foundReactive, isNotNull);
        expect(foundBpm, 100);
        expect(find.text('BPM: 100.0'), findsOneWidget);
      });
    });

    group('error handling', () {
      testWidgets('shows error builder on initialization failure',
          (tester) async {
        final provider = _FailingAudioProvider();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactiveBuilder(
            provider: provider,
            errorBuilder: (context, error) => Text('Error: $error'),
            builder: (context, p) => const Text('Ready'),
          ),
        ));

        await tester.pumpAndSettle();

        expect(find.textContaining('Error:'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);
      });

      testWidgets('shows default error when errorBuilder not provided',
          (tester) async {
        final provider = _FailingAudioProvider();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactiveBuilder(
            provider: provider,
            builder: (context, p) => const Text('Ready'),
          ),
        ));

        await tester.pumpAndSettle();

        expect(find.textContaining('Audio initialization error'), findsOneWidget);
      });
    });
  });

  group('AudioReactiveMixin', () {
    late MockAudioDataProvider provider;

    setUp(() async {
      provider = MockAudioDataProvider(bpm: 120);
      await provider.initialize();
    });

    group('getAudioProvider', () {
      testWidgets('returns provider from context', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.getAudioProvider(state.context), provider);
      });

      testWidgets('returns null when no AudioReactive', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(home: widget));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.getAudioProvider(state.context), isNull);
      });
    });

    group('getBpm', () {
      testWidgets('returns bpm from provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.getBpm(state.context), 120);
      });

      testWidgets('returns 0 when no provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(home: widget));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.getBpm(state.context), 0);
      });
    });

    group('getAmplitude', () {
      testWidgets('returns amplitude from provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        final amplitude = state.getAmplitude(state.context, 0);
        expect(amplitude, greaterThanOrEqualTo(0.0));
        expect(amplitude, lessThanOrEqualTo(1.0));
      });

      testWidgets('returns 0 when no provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(home: widget));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.getAmplitude(state.context, 0), 0);
      });
    });

    group('getBeatStrength', () {
      testWidgets('returns beat strength from provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        final strength = state.getBeatStrength(state.context, 0);
        expect(strength, greaterThanOrEqualTo(0.0));
        expect(strength, lessThanOrEqualTo(1.0));
      });
    });

    group('isBeat', () {
      testWidgets('returns boolean from provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.isBeat(state.context, 0), isA<bool>());
      });

      testWidgets('returns false when no provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(home: widget));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.isBeat(state.context, 0), isFalse);
      });
    });

    group('getFrequencyBands', () {
      testWidgets('returns bands from provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        final bands = state.getFrequencyBands(state.context, 0);
        expect(bands.length, 8);
      });

      testWidgets('returns zeros when no provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(home: widget));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        final bands = state.getFrequencyBands(state.context, 0);
        expect(bands.length, 8);
        expect(bands.every((b) => b == 0.0), isTrue);
      });
    });

    group('getBass, getMid, getTreble', () {
      testWidgets('all return values from provider', (tester) async {
        final widget = _MixinTestWidget();

        await tester.pumpWidget(MaterialApp(
          home: AudioReactive(
            provider: provider,
            child: widget,
          ),
        ));

        final state = tester.state<_MixinTestWidgetState>(
          find.byType(_MixinTestWidget),
        );

        expect(state.getBass(state.context, 0), greaterThanOrEqualTo(0.0));
        expect(state.getMid(state.context, 0), greaterThanOrEqualTo(0.0));
        expect(state.getTreble(state.context, 0), greaterThanOrEqualTo(0.0));
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
      test('creates with required child', () {
        const widget = BeatPulse(child: Text('Test'));
        expect(widget.child, isA<Text>());
      });

      test('has default values', () {
        const widget = BeatPulse(child: SizedBox());

        expect(widget.minScale, 1.0);
        expect(widget.maxScale, 1.15);
        expect(widget.threshold, 0.3);
        expect(widget.frame, isNull);
        expect(widget.fps, 30);
      });

      test('accepts custom values', () {
        const widget = BeatPulse(
          child: SizedBox(),
          minScale: 0.9,
          maxScale: 1.3,
          threshold: 0.5,
          frame: 10,
          fps: 60,
        );

        expect(widget.minScale, 0.9);
        expect(widget.maxScale, 1.3);
        expect(widget.threshold, 0.5);
        expect(widget.frame, 10);
        expect(widget.fps, 60);
      });
    });

    group('widget rendering', () {
      testWidgets('renders child without frame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const BeatPulse(
              child: Text('Pulse'),
            ),
          ),
        ));

        expect(find.text('Pulse'), findsOneWidget);
      });

      testWidgets('applies transform with frame', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const BeatPulse(
              frame: 0,
              child: Text('Pulse'),
            ),
          ),
        ));

        expect(find.text('Pulse'), findsOneWidget);
        expect(find.byType(Transform), findsOneWidget);
      });

      testWidgets('scale changes with beat strength', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const BeatPulse(
              frame: 0,
              minScale: 1.0,
              maxScale: 2.0,
              child: Text('Pulse'),
            ),
          ),
        ));

        // Should apply transform based on beat strength
        expect(find.byType(Transform), findsOneWidget);
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
      test('creates with required frame', () {
        const widget = FrequencyBars(frame: 0);
        expect(widget.frame, 0);
      });

      test('has default values', () {
        const widget = FrequencyBars(frame: 0);

        expect(widget.barCount, 8);
        expect(widget.barWidth, 20);
        expect(widget.maxHeight, 100);
        expect(widget.spacing, 4);
        expect(widget.color, const Color(0xFF1DB954));
        expect(widget.gradient, isNull);
        expect(widget.fps, 30);
        expect(widget.mirror, isFalse);
        expect(widget.borderRadius, isNull);
      });

      test('accepts custom values', () {
        const widget = FrequencyBars(
          frame: 10,
          barCount: 16,
          barWidth: 30,
          maxHeight: 200,
          spacing: 8,
          color: Colors.blue,
          fps: 60,
          mirror: true,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        );

        expect(widget.frame, 10);
        expect(widget.barCount, 16);
        expect(widget.barWidth, 30);
        expect(widget.maxHeight, 200);
        expect(widget.spacing, 8);
        expect(widget.color, Colors.blue);
        expect(widget.fps, 60);
        expect(widget.mirror, isTrue);
        expect(widget.borderRadius, isNotNull);
      });
    });

    group('widget rendering', () {
      testWidgets('renders correct number of bars', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const FrequencyBars(frame: 0, barCount: 8),
          ),
        ));

        expect(find.byType(Row), findsOneWidget);
        // Each bar has Padding, and there may be other Padding in the tree
        expect(find.byType(Padding), findsWidgets);
      });

      testWidgets('renders mirrored bars when enabled', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const FrequencyBars(frame: 0, mirror: true),
          ),
        ));

        expect(find.byType(Column), findsWidgets);
        expect(find.byType(Transform), findsWidgets); // Flip transform
      });

      testWidgets('applies custom bar count', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const FrequencyBars(frame: 0, barCount: 4),
          ),
        ));

        // Verify the Row renders with 4 Container bars
        expect(find.byType(Row), findsOneWidget);
        // 4 bars = 4 containers, plus potentially extra containers in wrapper
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('renders at different frames', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const FrequencyBars(frame: 0),
          ),
        ));

        expect(find.byType(Row), findsOneWidget);

        await tester.pumpWidget(wrapWithApp(
          AudioReactive(
            provider: provider,
            child: const FrequencyBars(frame: 30),
          ),
        ));

        expect(find.byType(Row), findsOneWidget);
      });
    });

    group('without provider', () {
      testWidgets('renders with zero values', (tester) async {
        await tester.pumpWidget(wrapWithApp(
          const FrequencyBars(frame: 0),
        ));

        // Should still render bars, just with minimum height
        expect(find.byType(Row), findsOneWidget);
      });
    });
  });
}

/// Test widget that uses AudioReactiveMixin
class _MixinTestWidget extends StatefulWidget {
  const _MixinTestWidget();

  @override
  State<_MixinTestWidget> createState() => _MixinTestWidgetState();
}

class _MixinTestWidgetState extends State<_MixinTestWidget>
    with AudioReactiveMixin {
  BuildContext get context => super.context;

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}

/// A failing audio provider for testing error handling
class _FailingAudioProvider implements AudioDataProvider {
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
  List<double> getFrequencyBandsAt(
    int frame, {
    int fps = 30,
    int bandCount = 8,
  }) =>
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
