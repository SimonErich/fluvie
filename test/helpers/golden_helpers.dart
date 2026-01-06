import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// =============================================================================
// Golden Test Configuration
// =============================================================================

/// Configuration for golden tests.
class GoldenConfig {
  /// Base path for golden files.
  static const String basePath = 'goldens';

  /// Default surface size for golden tests.
  static const Size defaultSize = Size(1080, 1920);

  /// Smaller size for quick golden comparisons.
  static const Size smallSize = Size(540, 960);

  /// Landscape size for golden tests.
  static const Size landscapeSize = Size(1920, 1080);

  /// Square size for golden tests.
  static const Size squareSize = Size(1080, 1080);
}

// =============================================================================
// Golden Test Utilities
// =============================================================================

/// Pumps a widget and compares it to a golden file.
///
/// The golden file is stored at `test/goldens/{name}.png`.
///
/// Example:
/// ```dart
/// testWidgets('my widget golden', (tester) async {
///   await expectGolden(
///     tester,
///     MyWidget(),
///     name: 'widgets/my_widget_default',
///   );
/// });
/// ```
Future<void> expectGolden(
  WidgetTester tester,
  Widget widget, {
  required String name,
  int frame = 0,
  Size size = GoldenConfig.defaultSize,
  int fps = 30,
  int durationInFrames = 300,
  bool useMaterialApp = true,
  String? reason,
}) async {
  // Set surface size
  await tester.binding.setSurfaceSize(size);

  // Pump the widget with proper context
  await tester.pumpWidget(wrapWithApp(
    widget,
    frame: frame,
    fps: fps,
    durationInFrames: durationInFrames,
    width: size.width.toInt(),
    height: size.height.toInt(),
    useMaterialApp: useMaterialApp,
  ));

  // Allow any animations to settle
  await tester.pump();

  // Compare to golden
  await expectLater(
    find.byType(useMaterialApp ? MaterialApp : Directionality),
    matchesGoldenFile('${GoldenConfig.basePath}/$name.png'),
    reason: reason,
  );

  // Reset surface size
  await tester.binding.setSurfaceSize(null);
}

/// Tests a widget at multiple frames and compares each to a golden file.
///
/// Each frame generates a golden file named `{baseName}_frame_{frame}.png`.
///
/// Example:
/// ```dart
/// testWidgets('animation goldens', (tester) async {
///   await expectGoldenAnimation(
///     tester,
///     AnimatedProp(
///       animation: PropAnimation.slideUp(),
///       child: Container(color: Colors.blue),
///     ),
///     baseName: 'animations/slide_up',
///     frames: [0, 15, 30],
///   );
/// });
/// ```
Future<void> expectGoldenAnimation(
  WidgetTester tester,
  Widget widget, {
  required String baseName,
  required List<int> frames,
  Size size = GoldenConfig.defaultSize,
  int fps = 30,
  int durationInFrames = 300,
}) async {
  for (final frame in frames) {
    await expectGolden(
      tester,
      widget,
      name: '${baseName}_frame_$frame',
      frame: frame,
      size: size,
      fps: fps,
      durationInFrames: durationInFrames,
    );
  }
}

/// Tests a widget at animation progress percentages.
///
/// Automatically calculates frame numbers based on the animation duration.
///
/// Example:
/// ```dart
/// await expectGoldenAtProgress(
///   tester,
///   myWidget,
///   baseName: 'my_widget',
///   startFrame: 0,
///   duration: 30,
///   progressPoints: [0.0, 0.25, 0.5, 0.75, 1.0],
/// );
/// ```
Future<void> expectGoldenAtProgress(
  WidgetTester tester,
  Widget widget, {
  required String baseName,
  required int startFrame,
  required int duration,
  List<double> progressPoints = const [0.0, 0.25, 0.5, 0.75, 1.0],
  Size size = GoldenConfig.defaultSize,
  int fps = 30,
}) async {
  final durationInFrames = startFrame + duration + 10; // Add buffer

  for (final progress in progressPoints) {
    final frame = startFrame + (duration * progress).round();
    final progressPct = (progress * 100).round();
    await expectGolden(
      tester,
      widget,
      name: '${baseName}_progress_$progressPct',
      frame: frame,
      size: size,
      fps: fps,
      durationInFrames: durationInFrames,
    );
  }
}

// =============================================================================
// Template Golden Helpers
// =============================================================================

/// Standard frames for testing template animations.
List<int> templateTestFrames(int recommendedLength) {
  return [
    0, // Start
    (recommendedLength * 0.25).round(), // 25%
    (recommendedLength * 0.5).round(), // 50%
    (recommendedLength * 0.75).round(), // 75%
    recommendedLength - 1, // End
  ];
}

/// Generates golden tests for a template at standard progress points.
Future<void> expectTemplateGoldens(
  WidgetTester tester,
  Widget template, {
  required String templateName,
  required int recommendedLength,
  Size size = GoldenConfig.defaultSize,
}) async {
  final frames = templateTestFrames(recommendedLength);
  await expectGoldenAnimation(
    tester,
    template,
    baseName: 'templates/$templateName',
    frames: frames,
    size: size,
    durationInFrames: recommendedLength + 10,
  );
}

// =============================================================================
// Golden Comparison Utilities
// =============================================================================

/// Compares two images and returns the percentage of different pixels.
///
/// Useful for custom golden comparison logic.
Future<double> compareImages(
  ui.Image image1,
  ui.Image image2, {
  double threshold = 0.01,
}) async {
  if (image1.width != image2.width || image1.height != image2.height) {
    return 1.0; // Completely different if sizes don't match
  }

  final byteData1 = await image1.toByteData();
  final byteData2 = await image2.toByteData();

  if (byteData1 == null || byteData2 == null) {
    return 1.0;
  }

  final bytes1 = byteData1.buffer.asUint8List();
  final bytes2 = byteData2.buffer.asUint8List();

  int differentPixels = 0;
  final totalPixels = image1.width * image1.height;

  for (var i = 0; i < bytes1.length; i += 4) {
    // Compare RGBA values with threshold
    final dr = (bytes1[i] - bytes2[i]).abs();
    final dg = (bytes1[i + 1] - bytes2[i + 1]).abs();
    final db = (bytes1[i + 2] - bytes2[i + 2]).abs();
    final da = (bytes1[i + 3] - bytes2[i + 3]).abs();

    // If any channel differs by more than threshold * 255
    final maxDiff = [dr, dg, db, da].reduce((a, b) => a > b ? a : b);
    if (maxDiff > threshold * 255) {
      differentPixels++;
    }
  }

  return differentPixels / totalPixels;
}

// =============================================================================
// Widget State Capture
// =============================================================================

/// Captures the current visual state of a widget for comparison.
///
/// Returns a description of key visual properties that can be compared
/// without full golden image comparison.
class WidgetStateCapture {
  final Map<String, dynamic> properties;

  WidgetStateCapture(this.properties);

  /// Captures transform properties from Transform widgets.
  static WidgetStateCapture fromTransform(Transform transform) {
    final matrix = transform.transform;
    return WidgetStateCapture({
      'type': 'Transform',
      'translation': {
        'x': matrix.getTranslation().x,
        'y': matrix.getTranslation().y,
        'z': matrix.getTranslation().z,
      },
      'scale': matrix.entry(0, 0), // Assumes uniform scale
    });
  }

  /// Captures opacity from Opacity widgets.
  static WidgetStateCapture fromOpacity(Opacity opacity) {
    return WidgetStateCapture({
      'type': 'Opacity',
      'opacity': opacity.opacity,
    });
  }

  /// Compares two captures and returns differences.
  Map<String, dynamic> diff(WidgetStateCapture other) {
    final differences = <String, dynamic>{};

    for (final key in properties.keys) {
      if (!other.properties.containsKey(key)) {
        differences[key] = {'this': properties[key], 'other': null};
      } else if (properties[key] != other.properties[key]) {
        differences[key] = {
          'this': properties[key],
          'other': other.properties[key],
        };
      }
    }

    for (final key in other.properties.keys) {
      if (!properties.containsKey(key)) {
        differences[key] = {'this': null, 'other': other.properties[key]};
      }
    }

    return differences;
  }

  @override
  String toString() => 'WidgetStateCapture($properties)';
}

// =============================================================================
// Golden Test Groups
// =============================================================================

/// Creates a group of golden tests for multiple variants of a widget.
///
/// Example:
/// ```dart
/// goldenTestGroup(
///   'Button',
///   variants: {
///     'default': MyButton(),
///     'disabled': MyButton(enabled: false),
///     'loading': MyButton(loading: true),
///   },
///   basePath: 'widgets/button',
/// );
/// ```
void goldenTestGroup(
  String description, {
  required Map<String, Widget> variants,
  required String basePath,
  Size size = GoldenConfig.defaultSize,
  int frame = 0,
}) {
  group(description, () {
    for (final entry in variants.entries) {
      testWidgets('${entry.key} golden', (tester) async {
        await expectGolden(
          tester,
          entry.value,
          name: '$basePath/${entry.key}',
          frame: frame,
          size: size,
        );
      });
    }
  });
}

/// Creates golden tests for a widget at multiple frames.
void goldenAnimationTestGroup(
  String description, {
  required Widget widget,
  required String basePath,
  required List<int> frames,
  Size size = GoldenConfig.defaultSize,
  int durationInFrames = 300,
}) {
  group(description, () {
    for (final frame in frames) {
      testWidgets('frame $frame golden', (tester) async {
        await expectGolden(
          tester,
          widget,
          name: '${basePath}_frame_$frame',
          frame: frame,
          size: size,
          durationInFrames: durationInFrames,
        );
      });
    }
  });
}
