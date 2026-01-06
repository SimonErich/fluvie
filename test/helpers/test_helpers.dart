import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/video_composition.dart';
import 'package:fluvie/src/presentation/time_consumer.dart';

/// Standard video dimensions for testing
class TestDimensions {
  static const int standardWidth = 1080;
  static const int standardHeight = 1920;
  static const int landscapeWidth = 1920;
  static const int landscapeHeight = 1080;
  static const int squareSize = 1080;
}

/// Wraps a widget with the necessary VideoComposition and FrameProvider context
/// for testing fluvie widgets.
///
/// This is the primary helper for widget tests. It provides:
/// - Directionality (LTR)
/// - MediaQuery with configurable dimensions
/// - VideoComposition context with fps, duration, and dimensions
/// - FrameProvider with the specified frame number
///
/// Example:
/// ```dart
/// await tester.pumpWidget(wrapWithApp(
///   AnimatedProp(
///     animation: PropAnimation.slideUp(),
///     child: Container(),
///   ),
///   frame: 15,
/// ));
/// ```
Widget wrapWithApp(
  Widget child, {
  int frame = 0,
  int fps = 30,
  int durationInFrames = 300,
  int width = TestDimensions.standardWidth,
  int height = TestDimensions.standardHeight,
  bool useMaterialApp = false,
}) {
  final content = Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(
        size: Size(width.toDouble(), height.toDouble()),
      ),
      child: VideoComposition(
        fps: fps,
        durationInFrames: durationInFrames,
        width: width,
        height: height,
        child: FrameProvider(frame: frame, child: child),
      ),
    ),
  );

  if (useMaterialApp) {
    return MaterialApp(home: Scaffold(body: content));
  }
  return content;
}

/// Wraps a widget with MaterialApp for tests requiring material widgets
Widget wrapWithMaterialApp(
  Widget child, {
  int frame = 0,
  int fps = 30,
  int durationInFrames = 300,
  int width = TestDimensions.standardWidth,
  int height = TestDimensions.standardHeight,
}) {
  return wrapWithApp(
    child,
    frame: frame,
    fps: fps,
    durationInFrames: durationInFrames,
    width: width,
    height: height,
    useMaterialApp: true,
  );
}

/// Tests a widget at multiple frames and calls [onFrame] for each.
///
/// Useful for verifying animation behavior at different points in time.
///
/// Example:
/// ```dart
/// await testAtFrames(
///   tester,
///   myAnimatedWidget,
///   [0, 15, 30],
///   (frame) {
///     if (frame == 0) {
///       expect(find.byType(Transform), findsOneWidget);
///     } else if (frame == 30) {
///       expect(find.byType(Transform), findsNothing);
///     }
///   },
/// );
/// ```
Future<void> testAtFrames(
  WidgetTester tester,
  Widget widget,
  List<int> frames, {
  required void Function(int frame) onFrame,
  int fps = 30,
  int durationInFrames = 300,
  int width = TestDimensions.standardWidth,
  int height = TestDimensions.standardHeight,
}) async {
  for (final frame in frames) {
    await tester.pumpWidget(wrapWithApp(
      widget,
      frame: frame,
      fps: fps,
      durationInFrames: durationInFrames,
      width: width,
      height: height,
    ));
    onFrame(frame);
  }
}

/// Tests a widget at multiple frames asynchronously.
///
/// Similar to [testAtFrames] but allows async operations in the callback.
Future<void> testAtFramesAsync(
  WidgetTester tester,
  Widget widget,
  List<int> frames, {
  required Future<void> Function(int frame) onFrame,
  int fps = 30,
  int durationInFrames = 300,
  int width = TestDimensions.standardWidth,
  int height = TestDimensions.standardHeight,
}) async {
  for (final frame in frames) {
    await tester.pumpWidget(wrapWithApp(
      widget,
      frame: frame,
      fps: fps,
      durationInFrames: durationInFrames,
      width: width,
      height: height,
    ));
    await onFrame(frame);
  }
}

/// Pumps a widget at a specific frame and returns the widget of type [T].
///
/// Useful for extracting widgets for property inspection.
Future<T> pumpAndFindWidget<T extends Widget>(
  WidgetTester tester,
  Widget widget, {
  int frame = 0,
  int fps = 30,
  int durationInFrames = 300,
}) async {
  await tester.pumpWidget(wrapWithApp(
    widget,
    frame: frame,
    fps: fps,
    durationInFrames: durationInFrames,
  ));
  return tester.widget<T>(find.byType(T));
}

// =============================================================================
// Custom Matchers
// =============================================================================

/// Creates a matcher for Transform widgets with expected translation.
///
/// Example:
/// ```dart
/// expect(find.byType(Transform), hasTranslation(Offset(0, 50)));
/// ```
Matcher hasTranslation(Offset expected, {double tolerance = 0.01}) {
  return _TransformMatcher(
    expected,
    tolerance,
    _TransformType.translation,
  );
}

/// Creates a matcher for Transform widgets with expected scale.
///
/// Example:
/// ```dart
/// expect(find.byType(Transform), hasScale(0.5));
/// ```
Matcher hasScale(double expected, {double tolerance = 0.01}) {
  return _TransformMatcher(
    expected,
    tolerance,
    _TransformType.scale,
  );
}

/// Creates a matcher for Opacity widgets with expected value.
///
/// Example:
/// ```dart
/// expect(find.byType(Opacity), hasOpacity(0.5));
/// ```
Matcher hasOpacity(double expected, {double tolerance = 0.01}) {
  return _OpacityMatcher(expected, tolerance);
}

/// Creates a matcher for widgets that should be visible (opacity > 0).
Matcher get isVisible => hasOpacity(greaterThan(0) as double);

/// Creates a matcher for widgets that should be invisible (opacity == 0).
Matcher get isInvisible => hasOpacity(0);

enum _TransformType { translation, scale, rotation }

class _TransformMatcher extends Matcher {
  final dynamic expected;
  final double tolerance;
  final _TransformType type;

  const _TransformMatcher(this.expected, this.tolerance, this.type);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is Finder) {
      final elements = item.evaluate();
      if (elements.isEmpty) return false;
      final widget = elements.first.widget;
      if (widget is Transform) {
        return _matchTransform(widget.transform, matchState);
      }
    }
    return false;
  }

  bool _matchTransform(Matrix4 transform, Map matchState) {
    switch (type) {
      case _TransformType.translation:
        final offset = expected as Offset;
        final translation = transform.getTranslation();
        final actualOffset = Offset(translation.x, translation.y);
        matchState['actual'] = actualOffset;
        return (actualOffset.dx - offset.dx).abs() < tolerance &&
            (actualOffset.dy - offset.dy).abs() < tolerance;
      case _TransformType.scale:
        final scale = expected as double;
        // Extract scale from diagonal elements
        final scaleX = transform.entry(0, 0);
        matchState['actual'] = scaleX;
        return (scaleX - scale).abs() < tolerance;
      case _TransformType.rotation:
        // TODO: Implement rotation matching
        return false;
    }
  }

  @override
  Description describe(Description description) {
    switch (type) {
      case _TransformType.translation:
        return description.add('has translation $expected');
      case _TransformType.scale:
        return description.add('has scale $expected');
      case _TransformType.rotation:
        return description.add('has rotation $expected');
    }
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('actual')) {
      return mismatchDescription.add('has value ${matchState['actual']}');
    }
    return mismatchDescription.add('is not a Transform widget');
  }
}

class _OpacityMatcher extends Matcher {
  final double expected;
  final double tolerance;

  const _OpacityMatcher(this.expected, this.tolerance);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is Finder) {
      final elements = item.evaluate();
      if (elements.isEmpty) return false;
      final widget = elements.first.widget;
      if (widget is Opacity) {
        matchState['actual'] = widget.opacity;
        return (widget.opacity - expected).abs() < tolerance;
      }
      if (widget is AnimatedOpacity) {
        matchState['actual'] = widget.opacity;
        return (widget.opacity - expected).abs() < tolerance;
      }
      if (widget is FadeTransition) {
        final opacity = widget.opacity.value;
        matchState['actual'] = opacity;
        return (opacity - expected).abs() < tolerance;
      }
    }
    return false;
  }

  @override
  Description describe(Description description) {
    return description.add('has opacity $expected (±$tolerance)');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState.containsKey('actual')) {
      return mismatchDescription.add('has opacity ${matchState['actual']}');
    }
    return mismatchDescription.add('is not an Opacity widget');
  }
}

// =============================================================================
// Utility Functions
// =============================================================================

/// Calculates the expected progress for a given frame within an animation.
///
/// Returns a value between 0.0 and 1.0.
double calculateProgress(int frame, int startFrame, int duration) {
  if (duration <= 0) return 1.0;
  final elapsed = frame - startFrame;
  if (elapsed < 0) return 0.0;
  if (elapsed >= duration) return 1.0;
  return elapsed / duration;
}

/// Calculates the expected frame number for a given time in seconds.
int timeToFrame(double seconds, {int fps = 30}) {
  return (seconds * fps).round();
}

/// Calculates the expected time in seconds for a given frame.
double frameToTime(int frame, {int fps = 30}) {
  return frame / fps;
}

/// Generates a list of frame numbers for testing animation progression.
///
/// Returns frames at 0%, 25%, 50%, 75%, and 100% of the animation.
List<int> animationProgressFrames(int startFrame, int duration) {
  return [
    startFrame,
    startFrame + (duration * 0.25).round(),
    startFrame + (duration * 0.5).round(),
    startFrame + (duration * 0.75).round(),
    startFrame + duration,
  ];
}

/// Creates a list of evenly spaced frames for testing.
List<int> evenlySpacedFrames(int start, int end, int count) {
  if (count <= 1) return [start];
  final step = (end - start) / (count - 1);
  return List.generate(count, (i) => start + (i * step).round());
}

// =============================================================================
// Test Data Generators
// =============================================================================

/// Generates test colors for visual testing.
List<Color> testColors({int count = 5}) {
  return [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.cyan,
    Colors.pink,
  ].take(count).toList();
}

/// Generates test text strings of varying lengths.
List<String> testStrings() {
  return [
    'Short',
    'Medium length text',
    'A much longer text string that might wrap',
    '', // Empty string
    'Single',
    '12345', // Numbers only
  ];
}

// =============================================================================
// Async Test Utilities
// =============================================================================

/// Waits for a condition to become true within a timeout.
///
/// Useful for waiting for async widget state changes.
Future<void> waitForCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(endTime)) {
    await tester.pump(pollInterval);
  }
  if (!condition()) {
    throw TimeoutException('Condition not met within $timeout');
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}

// =============================================================================
// Widget Finding Utilities
// =============================================================================

/// Finds a widget by its key string.
Finder findByKeyString(String key) => find.byKey(Key(key));

/// Finds all Text widgets containing the given string.
Finder findTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains(text) ?? false),
  );
}

/// Finds a widget by type within a parent.
Finder findDescendantByType<T extends Widget>(Finder parent) {
  return find.descendant(of: parent, matching: find.byType(T));
}

// =============================================================================
// Error Handling Utilities
// =============================================================================

/// Ignores overflow errors during widget tests.
///
/// Useful for testing templates that intentionally overflow (e.g., parallax scrolling).
/// This function modifies FlutterError.onError to filter out overflow errors.
///
/// Example:
/// ```dart
/// testWidgets('renders parallax correctly', (tester) async {
///   ignoreOverflowErrors();
///   await tester.pumpWidget(wrapWithApp(TriptychScroll(data: testData)));
///   expect(find.byType(TriptychScroll), findsOneWidget);
/// });
/// ```
void ignoreOverflowErrors() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception;
    final isOverflowError = exception is FlutterError &&
        (exception.message.contains('overflowed') ||
         exception.message.contains('OVERFLOWING'));
    if (!isOverflowError) {
      if (originalOnError != null) {
        originalOnError(details);
      }
    }
  };
  // Automatically restore after test completes
  addTearDown(() {
    FlutterError.onError = originalOnError;
  });
}

/// Wraps a test callback to ignore overflow errors with proper cleanup.
///
/// Automatically restores the original error handler after the test.
Future<void> withIgnoredOverflowErrors(Future<void> Function() test) async {
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exception;
    final isOverflowError = exception is FlutterError &&
        (exception.message.contains('overflowed') ||
         exception.message.contains('OVERFLOWING'));
    if (!isOverflowError) {
      if (originalHandler != null) {
        originalHandler(details);
      }
    }
  };
  try {
    await test();
  } finally {
    FlutterError.onError = originalHandler;
  }
}
