# Testing

> **Write and run tests for Fluvie**

This guide covers how to write effective tests for Fluvie contributions.

## Table of Contents

- [Overview](#overview)
- [Test Types](#test-types)
- [Running Tests](#running-tests)
- [Writing Widget Tests](#writing-widget-tests)
- [Gherkin Feature Tests](#gherkin-feature-tests)
- [Testing Animations](#testing-animations)
- [Testing Templates](#testing-templates)
- [Best Practices](#best-practices)

---

## Overview

Fluvie uses several testing approaches:

1. **Unit Tests**: Test individual functions and classes
2. **Widget Tests**: Test widget rendering and behavior
3. **Gherkin Tests**: BDD-style feature tests
4. **Integration Tests**: Test complete rendering pipeline

All tests should be deterministic and independent.

---

## Test Types

### Unit Tests

Test pure functions and simple classes:

```dart
// test/utils/interpolate_test.dart
void main() {
  group('interpolate', () {
    test('returns start value at frame 0', () {
      final result = interpolate(
        frame: 0,
        inputRange: [0, 100],
        outputRange: [0.0, 1.0],
      );
      expect(result, equals(0.0));
    });

    test('returns end value at final frame', () {
      final result = interpolate(
        frame: 100,
        inputRange: [0, 100],
        outputRange: [0.0, 1.0],
      );
      expect(result, equals(1.0));
    });

    test('interpolates midpoint correctly', () {
      final result = interpolate(
        frame: 50,
        inputRange: [0, 100],
        outputRange: [0.0, 1.0],
      );
      expect(result, closeTo(0.5, 0.001));
    });
  });
}
```

### Widget Tests

Test widget rendering with frame control:

```dart
// test/presentation/time_consumer_test.dart
void main() {
  testWidgets('TimeConsumer provides correct frame number', (tester) async {
    int? capturedFrame;

    await tester.pumpWidget(
      MaterialApp(
        home: RenderModeProvider(
          frameNotifier: FrameReadyNotifier(42),
          child: TimeConsumer(
            builder: (context, frame, _) {
              capturedFrame = frame;
              return Text('Frame: $frame');
            },
          ),
        ),
      ),
    );

    expect(capturedFrame, equals(42));
    expect(find.text('Frame: 42'), findsOneWidget);
  });
}
```

### Integration Tests

Test the full rendering pipeline:

```dart
// test/integration/render_service_test.dart
void main() {
  testWidgets('RenderService produces valid video', (tester) async {
    final video = Video(
      fps: 30,
      width: 320,
      height: 240,
      scenes: [
        Scene(
          durationInFrames: 30,
          children: [
            Container(color: Colors.blue),
          ],
        ),
      ],
    );

    final outputPath = '${Directory.systemTemp.path}/test_output.mp4';

    await RenderService.execute(
      composition: video,
      outputPath: outputPath,
      tester: tester,
    );

    // Verify output exists
    expect(File(outputPath).existsSync(), isTrue);

    // Verify video properties
    final info = await VideoProbeService.probe(outputPath);
    expect(info.width, equals(320));
    expect(info.height, equals(240));
    expect(info.fps, closeTo(30, 1));

    // Cleanup
    File(outputPath).deleteSync();
  });
}
```

---

## Running Tests

### All Tests

```bash
flutter test
```

### Specific Test File

```bash
flutter test test/fluvie_test.dart
```

### Specific Test Group

```bash
flutter test --name "TimeConsumer"
```

### With Verbose Output

```bash
flutter test --reporter expanded
```

### With Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Watch Mode

```bash
# Using flutter_test_watch (install separately)
flutter pub global activate flutter_test_watch
flutter_test_watch
```

---

## Writing Widget Tests

### Basic Widget Test

```dart
testWidgets('Scene renders children', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: FrameReadyNotifier(0),
        child: Scene(
          durationInFrames: 60,
          children: [
            Container(
              key: const Key('test-container'),
              color: Colors.red,
            ),
          ],
        ),
      ),
    ),
  );

  expect(find.byKey(const Key('test-container')), findsOneWidget);
});
```

### Testing Frame-Based Animation

```dart
testWidgets('Fade widget animates opacity', (tester) async {
  final frameNotifier = FrameReadyNotifier(0);

  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: frameNotifier,
        child: Fade(
          startFrame: 0,
          fadeInFrames: 30,
          child: Container(color: Colors.blue),
        ),
      ),
    ),
  );

  // Frame 0: Should be invisible
  expect(_getOpacity(tester), closeTo(0.0, 0.01));

  // Frame 15: Should be 50% visible
  frameNotifier.setFrame(15);
  await tester.pump();
  expect(_getOpacity(tester), closeTo(0.5, 0.01));

  // Frame 30: Should be fully visible
  frameNotifier.setFrame(30);
  await tester.pump();
  expect(_getOpacity(tester), closeTo(1.0, 0.01));
});

double _getOpacity(WidgetTester tester) {
  final fadeTransition = tester.widget<FadeTransition>(
    find.byType(FadeTransition),
  );
  return fadeTransition.opacity.value;
}
```

### Testing with Mock Data

```dart
testWidgets('StatCard displays formatted value', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: FrameReadyNotifier(100),  // After animation
        child: StatCard(
          title: 'Plays',
          value: 1000000,
          startFrame: 0,
          durationInFrames: 60,
        ),
      ),
    ),
  );

  expect(find.text('Plays'), findsOneWidget);
  expect(find.text('1,000,000'), findsOneWidget);  // Formatted
});
```

---

## Gherkin Feature Tests

Fluvie uses Gherkin-style BDD tests for feature specifications.

### Feature File

```gherkin
# test/features/video_composition.feature
Feature: Video Composition

  Scenario: Basic video rendering
    Given I define a VideoComposition with fps 30 and durationInFrames 90
    When the RenderService executes the composition
    Then the final video file duration is exactly 3 seconds

  Scenario: Scene transitions
    Given I define two consecutive timelines with a CrossFadeTransition lasting 15 frames
    When the FFmpegFilterGraphBuilder processes the transition point
    Then the output filtergraph uses an overlay filter with an enable and alpha expression
```

### Step Definitions

```dart
// test/features/step/i_define_a_videocomposition.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

class VideoCompositionContext {
  Video? video;
  String? outputPath;
}

final context = VideoCompositionContext();

void iDefineAVideoCompositionWithFps30AndDurationInFrames90() {
  context.video = Video(
    fps: 30,
    width: 1080,
    height: 1920,
    scenes: [
      Scene(
        durationInFrames: 90,
        children: [
          Container(color: Colors.blue),
        ],
      ),
    ],
  );
}

void theRenderServiceExecutesTheComposition(WidgetTester tester) async {
  context.outputPath = '${Directory.systemTemp.path}/test_${DateTime.now().millisecondsSinceEpoch}.mp4';

  await RenderService.execute(
    composition: context.video!,
    outputPath: context.outputPath!,
    tester: tester,
  );
}

void theFinalVideoFileDurationIsExactly3Seconds() async {
  final info = await VideoProbeService.probe(context.outputPath!);
  expect(info.duration.inSeconds, equals(3));
}
```

### Running Feature Tests

```bash
# Run all feature tests
flutter test test/features/

# Run specific feature
flutter test test/features/video_composition_test.dart
```

---

## Testing Animations

### PropAnimation Tests

```dart
void main() {
  group('PropAnimation.slideUp', () {
    test('starts at offset position', () {
      final animation = PropAnimation.slideUp(distance: 100);
      final transform = animation.transformAt(0.0);

      expect(transform.getTranslation().y, equals(100.0));
    });

    test('ends at original position', () {
      final animation = PropAnimation.slideUp(distance: 100);
      final transform = animation.transformAt(1.0);

      expect(transform.getTranslation().y, equals(0.0));
    });

    test('respects easing curve', () {
      final animation = PropAnimation.slideUp(
        distance: 100,
        curve: Curves.easeInOut,
      );

      // At 50% progress with easeInOut, should be close to middle
      final transform = animation.transformAt(0.5);
      expect(transform.getTranslation().y, closeTo(50.0, 5.0));
    });
  });
}
```

### Visual Animation Testing

```dart
testWidgets('AnimatedProp applies transform correctly', (tester) async {
  final frameNotifier = FrameReadyNotifier(0);

  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: frameNotifier,
        child: AnimatedProp(
          startFrame: 0,
          duration: 30,
          animation: PropAnimation.scale(from: 0.0, to: 1.0),
          child: Container(
            key: const Key('target'),
            width: 100,
            height: 100,
            color: Colors.red,
          ),
        ),
      ),
    ),
  );

  // Check transform at different frames
  for (final frame in [0, 15, 30]) {
    frameNotifier.setFrame(frame);
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.ancestor(
        of: find.byKey(const Key('target')),
        matching: find.byType(Transform),
      ),
    );

    final expectedScale = frame / 30;
    final matrix = transform.transform;
    expect(matrix.getMaxScaleOnAxis(), closeTo(expectedScale, 0.01));
  }
});
```

---

## Testing Templates

### Template Rendering Test

```dart
testWidgets('IntroTemplate renders all elements', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: FrameReadyNotifier(60),  // Mid-animation
        child: TheNeonGate(
          data: IntroData(
            title: 'Test Title',
            subtitle: '2024',
          ),
          theme: TemplateTheme.neon,
        ),
      ),
    ),
  );

  expect(find.text('Test Title'), findsOneWidget);
  expect(find.text('2024'), findsOneWidget);
});
```

### Template Theming Test

```dart
testWidgets('Template applies theme colors', (tester) async {
  const testTheme = TemplateTheme(
    colorPalette: ColorPalette(
      primary: Color(0xFFFF0000),
      secondary: Color(0xFF00FF00),
      accent: Color(0xFF0000FF),
      text: Colors.white,
      background: Colors.black,
    ),
    // ...
  );

  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: FrameReadyNotifier(0),
        child: TheNeonGate(
          data: IntroData(title: 'Test'),
          theme: testTheme,
        ),
      ),
    ),
  );

  // Find background container and verify color
  final container = tester.widget<Container>(
    find.byType(Container).first,
  );

  expect(container.color, equals(Colors.black));
});
```

---

## Best Practices

### 1. Use Meaningful Names

```dart
// Good
test('interpolate returns midpoint at 50% progress', () { ... });

// Bad
test('test1', () { ... });
```

### 2. One Assertion Per Test (When Practical)

```dart
// Good - focused tests
test('Fade starts invisible', () {
  expect(fade.opacityAt(0), equals(0.0));
});

test('Fade ends fully visible', () {
  expect(fade.opacityAt(1), equals(1.0));
});

// Acceptable - related assertions
test('Fade transitions correctly', () {
  expect(fade.opacityAt(0), equals(0.0));
  expect(fade.opacityAt(0.5), closeTo(0.5, 0.01));
  expect(fade.opacityAt(1), equals(1.0));
});
```

### 3. Test Edge Cases

```dart
group('FrameRange', () {
  test('handles zero-length range', () { ... });
  test('handles negative frames', () { ... });
  test('handles frame at exact boundary', () { ... });
});
```

### 4. Clean Up Test Resources

```dart
testWidgets('render test', (tester) async {
  final outputPath = '${Directory.systemTemp.path}/test.mp4';

  try {
    await RenderService.execute(
      composition: video,
      outputPath: outputPath,
      tester: tester,
    );

    // Assertions...
  } finally {
    // Always clean up
    if (File(outputPath).existsSync()) {
      File(outputPath).deleteSync();
    }
  }
});
```

### 5. Use Test Fixtures

```dart
// test/fixtures/test_videos.dart
Video createSimpleTestVideo({int length = 30}) {
  return Video(
    fps: 30,
    width: 320,
    height: 240,
    scenes: [
      Scene(
        durationInFrames: length,
        children: [Container(color: Colors.blue)],
      ),
    ],
  );
}

// In tests
test('renders simple video', () async {
  final video = createSimpleTestVideo(length: 60);
  // ...
});
```

---

## Related

- [Development Setup](development-setup.md) - Environment setup
- [Code Style](code-style.md) - Coding standards
- [Contributing](README.md) - Contribution overview

