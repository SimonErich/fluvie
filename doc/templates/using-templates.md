# Using Templates

> **Guide to using Fluvie's pre-built templates**

Templates provide ready-to-use scene compositions that you customize with your data, theme, and timing. This guide covers everything you need to know.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Data Contracts](#data-contracts)
- [Theming](#theming)
- [Timing](#timing)
- [Transitions](#transitions)
- [Examples](#examples)
- [Best Practices](#best-practices)

---

## Basic Usage

### 1. Choose a Template

Templates are organized by category:

- **Intro**: Opening scenes (`TheNeonGate`, `DigitalMirror`, `TheMixtape`)
- **Ranking**: List displays (`StackClimb`, `SlotMachine`, `TheSpotlight`)
- **DataViz**: Statistics (`LiquidMinutes`, `OrbitalMetrics`, `TheGrowthTree`)
- **Collage**: Photo grids (`TheGridShuffle`, `MosaicReveal`, `BentoRecap`)
- **Thematic**: Mood/vibe (`LofiWindow`, `GlitchReality`, `Kaleidoscope`)
- **Conclusion**: Endings (`TheSummaryPoster`, `ParticleFarewell`, `WrappedReceipt`)

### 2. Create Data

Each template requires specific data:

```dart
final introData = IntroData(
  title: 'Your 2024',
  subtitle: 'Wrapped',
  year: 2024,
);
```

### 3. Create Template

```dart
final template = TheNeonGate(
  data: introData,
  theme: TemplateTheme.neon,
  timing: TemplateTiming.dramatic,
);
```

### 4. Convert to Scene

```dart
final scene = template.toScene();

// Or with transitions
final scene = template.toSceneWithCrossFade();
```

### 5. Add to Video

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [scene],
)
```

---

## Data Contracts

### IntroData

For intro/identity templates:

```dart
IntroData(
  title: 'Your 2024',           // Required: main title
  subtitle: 'Wrapped',          // Optional: subtitle text
  year: 2024,                   // Optional: year number
  logoPath: 'assets/logo.png',  // Optional: logo image
  userName: 'John',             // Optional: user name
  profileImagePath: 'path.jpg', // Optional: profile image
)
```

### RankingData

For ranking/list templates:

```dart
RankingData(
  items: [                      // Required: list of items
    RankingItem(
      rank: 1,                  // Required: position (1 = first)
      label: 'Item Name',       // Required: display text
      subtitle: 'Details',      // Optional: secondary text
      value: 1234,              // Optional: numeric value
      imagePath: 'path.jpg',    // Optional: item image
      metadata: {'key': value}, // Optional: extra data
    ),
  ],
  title: 'Top Songs',           // Optional: section title
  subtitle: 'This Year',        // Optional: subtitle
  isTopList: true,              // Optional: is this a "top N" list?
)
```

### DataVizData

For data visualization templates:

```dart
DataVizData(
  metrics: [                    // Required: list of metrics
    MetricData(
      label: 'Hours Listened',  // Required: metric name
      value: 1234,              // Required: numeric value
      unit: 'hrs',              // Optional: unit suffix
      icon: Icons.timer,        // Optional: icon
      color: Colors.blue,       // Optional: color
      percentage: 0.75,         // Optional: percentage (0-1)
      trend: 1.0,               // Optional: trend (-1 to 1)
    ),
  ],
  title: 'Your Stats',          // Optional: title
  subtitle: 'In Numbers',       // Optional: subtitle
  maxValue: 2000,               // Optional: scale max
  categories: {'Pop': 45.0},    // Optional: category breakdown
  timeSeries: {0: 100, 60: 200}, // Optional: time data
)
```

**MetricData Factories:**

```dart
// Percentage with % suffix
MetricData.percentage(label: 'Growth', value: 45)

// Duration in minutes
MetricData.minutes(label: 'Daily', minutes: 120)

// Simple count
MetricData.count(label: 'Songs', count: 5000)
```

### CollageData

For collage/grid templates:

```dart
CollageData(
  images: [                     // Required: image paths
    'assets/photo1.jpg',
    'assets/photo2.jpg',
    'assets/photo3.jpg',
  ],
  title: 'Your Moments',        // Optional: title
  subtitle: '2024 Gallery',     // Optional: subtitle
  description: 'A year in...',  // Optional: description
  captions: ['One', 'Two'],     // Optional: per-image captions
  featuredIndex: 0,             // Optional: featured image index
  layout: TemplateCollageLayout.grid, // Optional: layout hint
  stats: {'Photos': 100},       // Optional: statistics
)
```

**Layout Options:**

```dart
TemplateCollageLayout.grid      // Standard grid
TemplateCollageLayout.masonry   // Pinterest-style
TemplateCollageLayout.featured  // One large + thumbnails
TemplateCollageLayout.strip     // Horizontal scroll
TemplateCollageLayout.diagonal  // Diagonal arrangement
```

### ThematicData

For thematic/vibe templates:

```dart
ThematicData(
  text: 'Your Music Journey',   // Required: main text
  title: 'The Vibe',            // Optional: title
  subtitle: '2024 Edition',     // Optional: subtitle
  description: 'Longer text',   // Optional: description
  images: ['path1.jpg'],        // Optional: image paths
  statValue: '1,234',           // Optional: main stat
  statLabel: 'hours',           // Optional: stat label
  theme: 'lofi',                // Optional: theme hint
  accentColor: Colors.purple,   // Optional: accent color
  metadata: {'key': value},     // Optional: extra data
)
```

### SummaryData

For conclusion/summary templates:

```dart
SummaryData(
  title: 'That\'s a Wrap!',     // Optional: title
  subtitle: 'See You Next Year', // Optional: subtitle
  name: 'John',                 // Optional: user name
  year: 2024,                   // Optional: year
  stats: {                      // Optional: key statistics
    'Hours': '1,234',
    'Songs': '5,678',
    'Artists': '234',
  },
  highlights: [                 // Optional: achievements
    HighlightItem(
      title: 'Top Fan',
      description: 'Top 1% of listeners',
      icon: Icons.star,
    ),
  ],
  message: 'Thanks for...',     // Optional: closing message
  ctaText: 'Share',             // Optional: button text
  shareUrl: 'https://...',      // Optional: share link
  qrData: 'https://...',        // Optional: QR code data
)
```

---

## Theming

### TemplateTheme

Customize colors and styling:

```dart
TemplateTheme(
  primaryColor: Colors.cyan,      // Main accent color
  secondaryColor: Colors.pink,    // Secondary accent
  backgroundColor: Colors.black,  // Background color
  textColor: Colors.white,        // Primary text color
  accentColor: Colors.purple,     // Additional accent
  surfaceColor: Color(0xFF222222), // Surface/card color
)
```

### Built-in Themes

```dart
// Neon/cyberpunk (bright colors on dark)
theme: TemplateTheme.neon

// Spotify-inspired (green on dark)
theme: TemplateTheme.spotify

// Clean minimal (subtle colors)
theme: TemplateTheme.minimal

// Warm sunset (orange/pink/purple)
theme: TemplateTheme.sunset

// Cool ocean (blues and teals)
theme: TemplateTheme.ocean
```

### Theme Merging

Themes merge with template defaults:

```dart
// Template has default neon theme
// Your custom colors override specific values
TheNeonGate(
  data: introData,
  theme: TemplateTheme(
    primaryColor: Colors.green,  // Overrides neon's cyan
    // Other colors use neon defaults
  ),
)
```

---

## Timing

### TemplateTiming

Control animation pacing:

```dart
TemplateTiming(
  entryDelay: 0,        // Frames before first animation
  entryDuration: 30,    // Entry animation length
  staggerDelay: 10,     // Delay between elements
  holdDuration: 60,     // Time at full visibility
  exitDelay: 0,         // Frames before exit starts
  exitDuration: 20,     // Exit animation length
)
```

### Built-in Timings

```dart
// Standard pacing (good default)
timing: TemplateTiming.standard

// Slower, more dramatic (for emphasis)
timing: TemplateTiming.dramatic

// Faster, snappier (for quick reveals)
timing: TemplateTiming.snappy

// Very quick (for rapid sequences)
timing: TemplateTiming.quick
```

---

## Transitions

### toScene() Options

```dart
template.toScene(
  durationInFrames: 180,                    // Override recommended length
  transitionIn: SceneTransition.crossFade(durationInFrames: 20),
  transitionOut: SceneTransition.slideLeft(durationInFrames: 15),
  fadeInFrames: 10,               // Scene fade in
  fadeOutFrames: 10,              // Scene fade out
)
```

### Convenience Methods

```dart
// Cross-fade both directions
template.toSceneWithCrossFade(
  length: 180,
  fadeDuration: 20,
)

// Slide transition
template.toSceneWithSlide(
  length: 180,
  direction: TransitionSlideDirection.left,
  slideDuration: 25,
)
```

### Slide Directions

```dart
TransitionSlideDirection.left   // From right
TransitionSlideDirection.right  // From left
TransitionSlideDirection.up     // From bottom
TransitionSlideDirection.down   // From top
```

---

## Examples

### Full Video with Templates

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  backgroundMusicAsset: 'assets/music.mp3',
  musicFadeInFrames: 60,
  musicFadeOutFrames: 90,
  scenes: [
    // Intro
    TheNeonGate(
      data: IntroData(
        title: 'Your 2024',
        subtitle: 'Wrapped',
        year: 2024,
      ),
      theme: TemplateTheme.neon,
    ).toSceneWithCrossFade(),

    // Top Songs
    StackClimb(
      data: RankingData(
        title: 'Top Songs',
        items: topSongs,
      ),
    ).toSceneWithSlide(direction: TransitionSlideDirection.left),

    // Stats
    LiquidMinutes(
      data: DataVizData(
        title: 'Your Stats',
        metrics: statsMetrics,
      ),
    ).toSceneWithCrossFade(),

    // Photo Memories
    TheGridShuffle(
      data: CollageData(
        title: 'Moments',
        images: photoList,
      ),
    ).toSceneWithSlide(direction: TransitionSlideDirection.up),

    // Conclusion
    TheSummaryPoster(
      data: SummaryData(
        title: 'That\'s a Wrap!',
        stats: finalStats,
        message: 'See you in 2025!',
      ),
    ).toSceneWithCrossFade(fadeDuration: 30),
  ],
)
```

### Consistent Theming

```dart
final myTheme = TemplateTheme(
  primaryColor: Color(0xFF1DB954),
  secondaryColor: Color(0xFF191414),
  backgroundColor: Color(0xFF121212),
  textColor: Colors.white,
);

Video(
  scenes: [
    TheNeonGate(data: introData, theme: myTheme).toScene(),
    StackClimb(data: rankingData, theme: myTheme).toScene(),
    TheSummaryPoster(data: summaryData, theme: myTheme).toScene(),
  ],
)
```

### Custom Timing

```dart
final slowTiming = TemplateTiming(
  entryDelay: 15,
  entryDuration: 45,
  staggerDelay: 20,
  holdDuration: 90,
  exitDuration: 30,
);

TheNeonGate(
  data: introData,
  timing: slowTiming,
).toScene(durationInFrames: 240)  // Longer scene for slow timing
```

---

## Best Practices

### 1. Match Length to Timing

Ensure scene length accommodates all animations:

```dart
final template = TheNeonGate(data: introData);

// Use recommended length
template.toScene()  // Uses template.recommendedLength

// Or calculate based on timing
template.toScene(durationInFrames: template.recommendedLength + 30)
```

### 2. Consistent Themes

Create a theme and reuse it:

```dart
final appTheme = TemplateTheme.neon.copyWith(
  primaryColor: myBrandColor,
);

// Apply to all templates
```

### 3. Smooth Transitions

Use matching transitions for flow:

```dart
// Good: Consistent direction
scene1.toSceneWithSlide(direction: TransitionSlideDirection.left)
scene2.toSceneWithSlide(direction: TransitionSlideDirection.left)

// Good: Alternating for variety
scene1.toSceneWithCrossFade()
scene2.toSceneWithSlide()
scene3.toSceneWithCrossFade()
```

### 4. Test Recommended Lengths

Templates have `recommendedLength` for a reason:

```dart
print(template.recommendedLength);  // Check what's recommended

// Override only if needed
template.toScene(durationInFrames: 200)
```

---

## Related

- [Templates Overview](README.md) - Template categories
- [Intro Templates](intro-templates.md)
- [Ranking Templates](ranking-templates.md)
- [DataViz Templates](data-viz-templates.md)
- [Collage Templates](collage-templates.md)
- [Thematic Templates](thematic-templates.md)
- [Conclusion Templates](conclusion-templates.md)
