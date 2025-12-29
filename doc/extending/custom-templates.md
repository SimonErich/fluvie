# Custom Templates

> **Package complete video templates**

Create reusable video templates that users can customize with their own data and styling.

## Table of Contents

- [Overview](#overview)
- [Template Architecture](#template-architecture)
- [Creating a Template](#creating-a-template)
- [Data Contracts](#data-contracts)
- [Theming](#theming)
- [Timing](#timing)
- [Testing Templates](#testing-templates)
- [Examples](#examples)

---

## Overview

Fluvie templates are pre-built video compositions that:

1. Accept structured data (text, images, metrics)
2. Support visual themes
3. Allow timing customization
4. Render as complete scenes

Templates are organized by category: intro, ranking, dataViz, collage, thematic, and conclusion.

---

## Template Architecture

### Base Class

All templates extend `WrappedTemplate`:

```dart
abstract class WrappedTemplate<T> extends StatelessWidget {
  /// The data contract for this template
  final T data;

  /// Visual theme configuration
  final TemplateTheme? theme;

  /// Animation timing configuration
  final TemplateTiming? timing;

  const WrappedTemplate({
    super.key,
    required this.data,
    this.theme,
    this.timing,
  });

  /// The template category
  TemplateCategory get category;

  /// Recommended scene length in frames
  int get recommendedLength;

  /// Build the template content
  @override
  Widget build(BuildContext context);

  /// Convert to a Scene widget
  Scene toScene({
    int? length,
    SceneTransition? transitionIn,
    SceneTransition? transitionOut,
  }) {
    return Scene(
      durationInFrames: length ?? recommendedLength,
      transitionIn: transitionIn,
      transitionOut: transitionOut,
      children: [this],
    );
  }
}
```

### Template Categories

```dart
enum TemplateCategory {
  intro,       // Opening sequences
  ranking,     // Top lists, leaderboards
  dataViz,     // Data visualization
  collage,     // Photo grids, galleries
  thematic,    // Mood, theme pieces
  conclusion,  // Endings, summaries
}
```

---

## Creating a Template

### Step 1: Define Data Contract

```dart
/// Data for the FeaturedArtist template
class FeaturedArtistData {
  final String artistName;
  final String? artistImage;
  final String topSong;
  final int playCount;
  final List<String> genres;

  const FeaturedArtistData({
    required this.artistName,
    this.artistImage,
    required this.topSong,
    required this.playCount,
    this.genres = const [],
  });
}
```

### Step 2: Create Template Class

```dart
class FeaturedArtist extends WrappedTemplate<FeaturedArtistData> {
  const FeaturedArtist({
    super.key,
    required super.data,
    super.theme,
    super.timing,
  });

  @override
  TemplateCategory get category => TemplateCategory.thematic;

  @override
  int get recommendedLength => 150;  // 5 seconds at 30fps

  @override
  Widget build(BuildContext context) {
    final colors = theme?.colorPalette ?? TemplateTheme.neon.colorPalette;
    final timingConfig = timing ?? TemplateTiming.standard;

    return LayerStack(
      children: [
        // Background
        Layer(
          child: Background(
            colors: [colors.primary, colors.secondary],
          ),
        ),

        // Artist image
        if (data.artistImage != null)
          Layer(
            child: AnimatedProp(
              startFrame: timingConfig.startDelay,
              duration: 30,
              animation: PropAnimation.fadeIn(),
              child: Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      data.artistImage!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Artist name
        Layer(
          child: AnimatedProp(
            startFrame: timingConfig.startDelay + 15,
            duration: 30,
            animation: PropAnimation.slideUp(distance: 50),
            child: Positioned(
              top: 350,
              left: 40,
              right: 40,
              child: Text(
                data.artistName,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Play count
        Layer(
          child: AnimatedProp(
            startFrame: timingConfig.startDelay + 30,
            duration: 30,
            animation: PropAnimation.fadeIn(),
            child: Positioned(
              top: 420,
              left: 40,
              right: 40,
              child: CounterText(
                from: 0,
                to: data.playCount,
                startFrame: timingConfig.startDelay + 40,
                durationInFrames: 45,
                suffix: ' plays',
                style: TextStyle(
                  fontSize: 32,
                  color: colors.accent,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Top song
        Layer(
          child: AnimatedProp(
            startFrame: timingConfig.startDelay + 60,
            duration: 30,
            animation: PropAnimation.combine([
              PropAnimation.fadeIn(),
              PropAnimation.slideUp(distance: 20),
            ]),
            child: Positioned(
              top: 500,
              left: 40,
              right: 40,
              child: Column(
                children: [
                  Text(
                    'Top Song',
                    style: TextStyle(
                      fontSize: 18,
                      color: colors.text.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.topSong,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Genre tags
        if (data.genres.isNotEmpty)
          Layer(
            child: AnimatedProp(
              startFrame: timingConfig.startDelay + 90,
              duration: 30,
              animation: PropAnimation.fadeIn(),
              child: Positioned(
                bottom: 100,
                left: 40,
                right: 40,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: data.genres.map((genre) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.accent),
                      ),
                      child: Text(
                        genre,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

### Step 3: Usage

```dart
final artistScene = FeaturedArtist(
  data: FeaturedArtistData(
    artistName: 'Taylor Swift',
    artistImage: 'assets/taylor.jpg',
    topSong: 'Anti-Hero',
    playCount: 1234567,
    genres: ['Pop', 'Country', 'Indie'],
  ),
  theme: TemplateTheme.spotify,
  timing: TemplateTiming.dramatic,
).toScene(
  transitionIn: SceneTransition.fade(),
  transitionOut: SceneTransition.slideLeft(),
);
```

---

## Data Contracts

### Design Principles

1. **Required vs Optional**: Make essential fields required, extras optional
2. **Sensible Defaults**: Provide defaults where appropriate
3. **Type Safety**: Use proper types (not just strings)
4. **Validation**: Validate data in constructors if needed

### Example Data Contracts

```dart
/// For countdown/list templates
class CountdownData {
  final List<CountdownItem> items;
  final String? title;
  final String? subtitle;

  const CountdownData({
    required this.items,
    this.title,
    this.subtitle,
  }) : assert(items.length >= 3, 'Need at least 3 items');
}

class CountdownItem {
  final int rank;
  final String name;
  final String? image;
  final String? metric;

  const CountdownItem({
    required this.rank,
    required this.name,
    this.image,
    this.metric,
  });
}

/// For stat display templates
class StatsData {
  final String title;
  final List<StatMetric> metrics;

  const StatsData({
    required this.title,
    required this.metrics,
  });
}

class StatMetric {
  final String label;
  final num value;
  final String? unit;
  final String? icon;

  const StatMetric({
    required this.label,
    required this.value,
    this.unit,
    this.icon,
  });
}
```

---

## Theming

### TemplateTheme

```dart
class TemplateTheme {
  final ColorPalette colorPalette;
  final Typography typography;
  final ShapeStyle shapeStyle;

  const TemplateTheme({
    required this.colorPalette,
    required this.typography,
    required this.shapeStyle,
  });

  // Built-in themes
  static const neon = TemplateTheme(/* ... */);
  static const spotify = TemplateTheme(/* ... */);
  static const minimal = TemplateTheme(/* ... */);
  static const retro = TemplateTheme(/* ... */);
}

class ColorPalette {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color text;
  final Color background;

  const ColorPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.text,
    required this.background,
  });
}
```

### Using Themes in Templates

```dart
@override
Widget build(BuildContext context) {
  // Get theme with fallback
  final colors = theme?.colorPalette ?? TemplateTheme.neon.colorPalette;
  final typography = theme?.typography ?? TemplateTheme.neon.typography;

  return Container(
    color: colors.background,
    child: Text(
      data.title,
      style: TextStyle(
        fontFamily: typography.headingFont,
        fontSize: typography.headingSize,
        color: colors.text,
      ),
    ),
  );
}
```

### Custom Theme

```dart
final customTheme = TemplateTheme(
  colorPalette: ColorPalette(
    primary: const Color(0xFF6C63FF),
    secondary: const Color(0xFF3F3D56),
    accent: const Color(0xFFFF6584),
    text: Colors.white,
    background: const Color(0xFF1A1A2E),
  ),
  typography: Typography(
    headingFont: 'Montserrat',
    bodyFont: 'Open Sans',
    headingSize: 48,
    bodySize: 18,
  ),
  shapeStyle: ShapeStyle(
    borderRadius: 16,
    shadowBlur: 20,
  ),
);
```

---

## Timing

### TemplateTiming

```dart
class TemplateTiming {
  final int startDelay;        // Frames before first animation
  final int elementStagger;    // Frames between element animations
  final int animationDuration; // Default animation length
  final Curve animationCurve;  // Default easing

  const TemplateTiming({
    this.startDelay = 15,
    this.elementStagger = 10,
    this.animationDuration = 30,
    this.animationCurve = Curves.easeOutCubic,
  });

  // Presets
  static const standard = TemplateTiming();
  static const dramatic = TemplateTiming(
    startDelay: 30,
    elementStagger: 20,
    animationDuration: 45,
    animationCurve: Curves.easeInOutCubic,
  );
  static const snappy = TemplateTiming(
    startDelay: 10,
    elementStagger: 5,
    animationDuration: 15,
    animationCurve: Curves.easeOut,
  );
}
```

### Using Timing in Templates

```dart
@override
Widget build(BuildContext context) {
  final t = timing ?? TemplateTiming.standard;

  return VColumn(
    stagger: StaggerConfig(
      delayBetweenItems: t.elementStagger,
      animation: PropAnimation.slideUp(
        duration: t.animationDuration,
        curve: t.animationCurve,
      ),
    ),
    children: [
      // Element 1: starts at t.startDelay
      AnimatedProp(
        startFrame: t.startDelay,
        duration: t.animationDuration,
        animation: PropAnimation.fadeIn(curve: t.animationCurve),
        child: Text(data.title),
      ),
      // Element 2: starts at t.startDelay + t.elementStagger
      // ... and so on
    ],
  );
}
```

---

## Testing Templates

### Basic Template Test

```dart
void main() {
  group('FeaturedArtist', () {
    testWidgets('renders with minimal data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderModeProvider(
            frameNotifier: FrameReadyNotifier(0),
            child: FeaturedArtist(
              data: FeaturedArtistData(
                artistName: 'Test Artist',
                topSong: 'Test Song',
                playCount: 1000,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Artist'), findsOneWidget);
      expect(find.text('Test Song'), findsOneWidget);
    });

    testWidgets('applies theme colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RenderModeProvider(
            frameNotifier: FrameReadyNotifier(0),
            child: FeaturedArtist(
              data: FeaturedArtistData(
                artistName: 'Test',
                topSong: 'Song',
                playCount: 100,
              ),
              theme: TemplateTheme.spotify,
            ),
          ),
        ),
      );

      // Verify theme is applied
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(TemplateTheme.spotify.colorPalette.background));
    });
  });
}
```

### Animation Timeline Test

```dart
testWidgets('animations follow timing config', (tester) async {
  final frameNotifier = FrameReadyNotifier(0);
  final timing = TemplateTiming(startDelay: 30);

  await tester.pumpWidget(
    MaterialApp(
      home: RenderModeProvider(
        frameNotifier: frameNotifier,
        child: FeaturedArtist(
          data: testData,
          timing: timing,
        ),
      ),
    ),
  );

  // Before start delay - should not be visible
  frameNotifier.setFrame(0);
  await tester.pump();
  expect(find.text(testData.artistName).evaluate().first.renderObject!.paintBounds.isEmpty, isTrue);

  // After animation - should be visible
  frameNotifier.setFrame(100);
  await tester.pump();
  expect(find.text(testData.artistName), findsOneWidget);
});
```

---

## Examples

### Complete Template Example

```dart
/// A template showing a "Year in Review" title card
class YearInReviewIntro extends WrappedTemplate<YearIntroData> {
  const YearInReviewIntro({
    super.key,
    required super.data,
    super.theme,
    super.timing,
  });

  @override
  TemplateCategory get category => TemplateCategory.intro;

  @override
  int get recommendedLength => 120;

  @override
  Widget build(BuildContext context) {
    final colors = theme?.colorPalette ?? TemplateTheme.neon.colorPalette;
    final t = timing ?? TemplateTiming.dramatic;

    return LayerStack(
      children: [
        // Animated gradient background
        Layer(
          child: TimeConsumer(
            builder: (context, frame, _) {
              final hue = (frame * 0.5) % 360;
              return Background(
                colors: [
                  HSLColor.fromAHSL(1, hue, 0.8, 0.3).toColor(),
                  HSLColor.fromAHSL(1, (hue + 60) % 360, 0.8, 0.2).toColor(),
                ],
              );
            },
          ),
        ),

        // Year number
        Layer(
          child: VCenter(
            child: VColumn(
              children: [
                AnimatedProp(
                  startFrame: t.startDelay,
                  duration: 60,
                  animation: PropAnimation.combine([
                    PropAnimation.scale(from: 3.0, to: 1.0),
                    PropAnimation.fadeIn(),
                  ]),
                  child: Text(
                    '${data.year}',
                    style: TextStyle(
                      fontSize: 200,
                      fontWeight: FontWeight.w900,
                      color: colors.text,
                    ),
                  ),
                ),
                AnimatedProp(
                  startFrame: t.startDelay + 30,
                  duration: 30,
                  animation: PropAnimation.slideUp(distance: 30),
                  child: Text(
                    'WRAPPED',
                    style: TextStyle(
                      fontSize: 48,
                      letterSpacing: 20,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Particle overlay
        Layer(
          child: ParticleEffect.sparkles(
            startFrame: t.startDelay,
            color: colors.accent,
          ),
        ),
      ],
    );
  }
}

class YearIntroData {
  final int year;
  final String? username;

  const YearIntroData({
    required this.year,
    this.username,
  });
}
```

---

## Related

- [Templates Overview](../templates/README.md) - Built-in templates
- [Using Templates](../templates/using-templates.md) - Template usage guide
- [Custom Animations](custom-animations.md) - Animation system
- [Custom Effects](custom-effects.md) - Effect system

