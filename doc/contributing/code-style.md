# Code Style

> **Coding standards and conventions for Fluvie**

Follow these guidelines to maintain consistency across the codebase.

## Table of Contents

- [Dart Style](#dart-style)
- [Naming Conventions](#naming-conventions)
- [Documentation](#documentation)
- [Widget Guidelines](#widget-guidelines)
- [Testing Standards](#testing-standards)
- [Git Conventions](#git-conventions)

---

## Dart Style

### Formatting

Use the Dart formatter with 80-character line length:

```bash
dart format --line-length 80 .
```

Configure your IDE to format on save.

### analysis_options.yaml

The project uses strict analysis rules:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - avoid_print
    - avoid_unnecessary_containers
    - prefer_single_quotes
```

### Imports

Order imports in groups:

```dart
// Dart core
import 'dart:async';
import 'dart:math';

// Flutter
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

// External packages
import 'package:json_annotation/json_annotation.dart';

// Internal packages
import 'package:fluvie/fluvie.dart';

// Relative imports
import '../utils/interpolate.dart';
import 'time_consumer.dart';
```

### Prefer const

Use `const` wherever possible:

```dart
// Good
const EdgeInsets.all(16)
const TextStyle(fontSize: 24)
const SizedBox(height: 8)

// In constructors
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});  // const constructor
}
```

---

## Naming Conventions

### Classes

| Type | Convention | Example |
|------|------------|---------|
| Widgets | PascalCase | `TimeConsumer`, `VideoComposition` |
| Data classes | PascalCase | `RenderConfig`, `AudioConfig` |
| Enums | PascalCase | `TemplateCategory`, `RenderQuality` |
| Mixins | PascalCase with "Mixin" suffix | `TemplateMixin` |
| Extensions | PascalCase with context | `IterableExtension` |

### Files

| Type | Convention | Example |
|------|------------|---------|
| Widgets | snake_case | `time_consumer.dart` |
| Tests | snake_case with `_test` suffix | `time_consumer_test.dart` |
| Generated | snake_case with `.g.dart` | `render_config.g.dart` |

### Variables and Functions

```dart
// Variables - camelCase
final frameNumber = 42;
final totalDuration = Duration(seconds: 5);

// Private - underscore prefix
final _internalState = {};
void _processFrame() {}

// Constants - camelCase or SCREAMING_SNAKE_CASE for app-wide
const defaultFps = 30;
const MAX_FRAME_CACHE_SIZE = 1000;

// Functions - camelCase, verb-first
void renderFrame() {}
Future<void> processVideo() async {}
bool isValidFrame(int frame) => frame >= 0;
```

### Widget Parameters

```dart
class MyWidget extends StatelessWidget {
  // Required parameters first
  final String title;
  final int startFrame;

  // Optional parameters with defaults
  final int durationInFrames;
  final Curve curve;

  // Callbacks
  final VoidCallback? onComplete;

  // Child/children last
  final Widget child;

  const MyWidget({
    super.key,
    required this.title,
    required this.startFrame,
    this.durationInFrames = 30,
    this.curve = Curves.easeOut,
    this.onComplete,
    required this.child,
  });
}
```

---

## Documentation

### Class Documentation

```dart
/// A widget that provides the current frame number to its descendants.
///
/// [TimeConsumer] rebuilds its child whenever the frame changes, making it
/// the primary way to create frame-based animations in Fluvie.
///
/// ## Example
///
/// ```dart
/// TimeConsumer(
///   builder: (context, frame, child) {
///     return Text('Frame: $frame');
///   },
/// )
/// ```
///
/// See also:
/// * [RenderModeProvider], which provides the frame notifier
/// * [Fade], a widget that uses TimeConsumer internally
class TimeConsumer extends StatelessWidget {
```

### Property Documentation

```dart
/// The frame at which the animation starts.
///
/// This is relative to the scene's start frame. A [startFrame] of 30
/// means the animation begins one second into a 30fps scene.
final int startFrame;

/// The duration of the animation in frames.
///
/// At 30fps, a [durationInFrames] of 60 equals 2 seconds.
/// Defaults to 30 frames (1 second at 30fps).
final int durationInFrames;
```

### Method Documentation

```dart
/// Calculates the opacity at the given [progress].
///
/// The [progress] value ranges from 0.0 (start) to 1.0 (end).
///
/// Returns a value between 0.0 (invisible) and 1.0 (fully visible).
///
/// Throws [ArgumentError] if [progress] is outside the 0.0-1.0 range.
double opacityAt(double progress) {
  if (progress < 0 || progress > 1) {
    throw ArgumentError.value(progress, 'progress', 'Must be between 0 and 1');
  }
  return _curve.transform(progress);
}
```

### When to Document

**Always document:**
- Public classes
- Public methods
- Public properties
- Complex logic

**Skip documentation for:**
- Obvious getters/setters
- Private implementation details
- Self-documenting code

```dart
// Skip - obvious
int get length => _length;

// Document - non-obvious behavior
/// Returns the effective length, accounting for trim settings.
///
/// This may be less than [originalLength] if the video is trimmed.
int get effectiveLength => _length - _trimStart - _trimEnd;
```

---

## Widget Guidelines

### Prefer Composition

```dart
// Good - composed from smaller widgets
class StatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedProp(
      animation: PropAnimation.fadeIn(),
      child: Container(
        child: Column(
          children: [
            _buildTitle(),
            _buildValue(),
          ],
        ),
      ),
    );
  }
}

// Avoid - monolithic widgets with everything inline
```

### Use const Constructors

```dart
class MyWidget extends StatelessWidget {
  final String text;

  // const constructor
  const MyWidget({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    // Use const for static children
    return const Column(
      children: [
        SizedBox(height: 8),
        Divider(),
      ],
    );
  }
}
```

### Keep build() Clean

```dart
// Good - extracted methods
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      _buildHeader(),
      _buildContent(),
      _buildFooter(),
    ],
  );
}

Widget _buildHeader() { ... }
Widget _buildContent() { ... }
Widget _buildFooter() { ... }

// Avoid - everything in build()
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // 50 lines of header code...
      // 100 lines of content code...
      // 30 lines of footer code...
    ],
  );
}
```

### Avoid Expensive Operations in build()

```dart
// Bad - calculates every rebuild
@override
Widget build(BuildContext context) {
  final expensiveData = computeExpensiveData();  // Avoid!
  return Text(expensiveData.toString());
}

// Good - compute in initState or use memoization
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final String _cachedData;

  @override
  void initState() {
    super.initState();
    _cachedData = computeExpensiveData();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_cachedData);
  }
}
```

---

## Testing Standards

### Test File Structure

```dart
void main() {
  // Group related tests
  group('ClassName', () {
    // Setup shared across tests
    late SomeClass instance;

    setUp(() {
      instance = SomeClass();
    });

    tearDown(() {
      instance.dispose();
    });

    // Test specific behavior
    group('methodName', () {
      test('does X when Y', () {
        // Arrange
        final input = 'test';

        // Act
        final result = instance.methodName(input);

        // Assert
        expect(result, equals(expected));
      });

      test('throws when invalid input', () {
        expect(
          () => instance.methodName(null),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
```

### Widget Test Structure

```dart
testWidgets('description of what is being tested', (tester) async {
  // Arrange - set up widget
  await tester.pumpWidget(
    MaterialApp(
      home: MyWidget(),
    ),
  );

  // Act - interact with widget
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();

  // Assert - verify result
  expect(find.text('Expected'), findsOneWidget);
});
```

---

## Git Conventions

### Branch Names

```
feature/add-particle-effects
fix/audio-sync-issue
docs/update-tutorial
refactor/simplify-render-pipeline
```

### Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructure
- `test`: Add/update tests
- `chore`: Maintenance

**Examples:**

```
feat(templates): add StackClimb ranking template

Implements a new ranking template that reveals items by stacking
and sliding cards off screen.

Closes #123
```

```
fix(audio): correct sync anchor timing calculation

The sync offset was being applied in the wrong direction,
causing audio to play late instead of early.
```

```
docs(widgets): add TimeConsumer documentation

- Add comprehensive guide with examples
- Include performance tips
- Link to related widgets
```

### Pull Request Guidelines

1. **Title**: Use conventional commit format
2. **Description**: Explain what and why
3. **Testing**: Describe how to test
4. **Screenshots**: Include for visual changes
5. **Checklist**: Mark completed items

---

## Related

- [Development Setup](development-setup.md) - Environment setup
- [Testing](testing.md) - Testing guidelines
- [Contributing](README.md) - Contribution overview

