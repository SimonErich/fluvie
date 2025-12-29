# DataViz Templates

> **Visualize statistics and metrics with engaging animations**

DataViz templates transform numbers into visually compelling scenes, perfect for displaying listening hours, counts, percentages, and other metrics.

## Table of Contents

- [LiquidMinutes](#liquidminutes)
- [OrbitalMetrics](#orbitalmetrics)
- [BinaryRain](#binaryrain)
- [TheGrowthTree](#thegrowthtree)
- [FrequencyGlow](#frequencyglow)

---

## LiquidMinutes

> Container fills with liquid representing time/data

Creates a satisfying visualization where a container (glass, jar, etc.) fills up with animated liquid. The liquid level represents the main metric, with bubbles and waves for visual interest.

### Visual Style

- Animated liquid fill animation
- Wave effect at liquid surface
- Rising bubbles
- Glass shine effect

### Best For

- Total listening time
- Hours/minutes metrics
- Progress indicators

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `DataVizData` | **required** | Data visualization data |
| `theme` | `TemplateTheme?` | `ocean` | Visual theme |
| `containerShape` | `ContainerShape` | `glass` | Shape of container |
| `liquidColor` | `Color?` | `null` | Custom liquid color |
| `showBubbles` | `bool` | `true` | Show rising bubbles |
| `fillTarget` | `double` | `0.85` | Target fill level (0-1) |

### Container Shapes

```dart
ContainerShape.glass   // Wine glass shape
ContainerShape.jar     // Mason jar shape
ContainerShape.bottle  // Bottle shape
ContainerShape.beaker  // Lab beaker shape
```

### Usage

```dart
LiquidMinutes(
  data: DataVizData(
    title: 'Minutes Listened',
    subtitle: 'This Year',
    metrics: [
      MetricData(label: 'Total Time', value: 45000),
    ],
    total: 45000,
  ),
  containerShape: ContainerShape.glass,
  showBubbles: true,
  fillTarget: 0.85,
).toSceneWithCrossFade()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## OrbitalMetrics

> Metrics orbit around a central point

Creates a space-themed visualization where metrics circle around a central element, with each data point represented as an orbiting body.

### Visual Style

- Central focus element
- Orbiting metric indicators
- Orbital path rings
- Glowing trail effects

### Best For

- Multiple related metrics
- Category breakdowns
- Interconnected data

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `DataVizData` | **required** | Data visualization data |
| `theme` | `TemplateTheme?` | `midnight` | Visual theme |
| `orbitSpeed` | `double` | `0.5` | Rotation speed |
| `showOrbits` | `bool` | `true` | Show orbital paths |
| `showTrails` | `bool` | `true` | Show trailing effects |

### Usage

```dart
OrbitalMetrics(
  data: DataVizData(
    title: 'Your Music Universe',
    metrics: [
      MetricData(label: 'Pop', value: 45, color: Colors.pink),
      MetricData(label: 'Rock', value: 30, color: Colors.red),
      MetricData(label: 'Hip-Hop', value: 15, color: Colors.purple),
      MetricData(label: 'Electronic', value: 10, color: Colors.blue),
    ],
  ),
  orbitSpeed: 0.5,
  showOrbits: true,
).toScene()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## BinaryRain

> Matrix-style binary rain revealing data

Creates a cyberpunk-inspired visualization where numbers rain down the screen, eventually coalescing to reveal the main statistic.

### Visual Style

- Falling binary/number streams
- Matrix-like rain effect
- Numbers coalesce into statistic
- Glow effects

### Best For

- Tech-themed stats
- Digital metrics
- Count reveals

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `DataVizData` | **required** | Data visualization data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `rainDensity` | `double` | `0.7` | Density of falling characters |
| `useBinary` | `bool` | `true` | Use 0s and 1s vs random digits |
| `revealSpeed` | `double` | `1.0` | Speed of reveal animation |

### Usage

```dart
BinaryRain(
  data: DataVizData(
    title: 'Total Streams',
    metrics: [
      MetricData.count(label: 'Streams', count: 1234567),
    ],
    total: 1234567,
  ),
  theme: TemplateTheme.neon,
  rainDensity: 0.7,
  useBinary: true,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## TheGrowthTree

> Tree grows with branches representing data categories

Creates an organic visualization where a tree grows from the bottom, with branches representing different data categories and their proportions.

### Visual Style

- Animated tree growth
- Branches proportional to data
- Leaves/blossoms for detail
- Organic growth animation

### Best For

- Growth metrics
- Category breakdowns
- Year-over-year comparisons

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `DataVizData` | **required** | Data visualization data |
| `theme` | `TemplateTheme?` | `sunset` | Visual theme |
| `growthSpeed` | `double` | `1.0` | Tree growth speed |
| `showLeaves` | `bool` | `true` | Show decorative leaves |
| `showLabels` | `bool` | `true` | Show category labels |

### Usage

```dart
TheGrowthTree(
  data: DataVizData(
    title: 'Your Growth',
    subtitle: 'This Year',
    metrics: [
      MetricData(label: 'Songs', value: 500, color: Colors.green),
      MetricData(label: 'Artists', value: 120, color: Colors.orange),
      MetricData(label: 'Albums', value: 80, color: Colors.red),
    ],
  ),
  theme: TemplateTheme.sunset,
  showLeaves: true,
).toScene()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## FrequencyGlow

> Audio frequency bars visualization

Creates a music-inspired visualization with animated frequency bars that pulse and glow to represent metrics.

### Visual Style

- Audio equalizer style bars
- Pulsing/breathing animation
- Glow effects
- Reactive movement

### Best For

- Music-related metrics
- Audio statistics
- Volume/intensity data

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `DataVizData` | **required** | Data visualization data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `barCount` | `int` | `12` | Number of frequency bars |
| `pulseSpeed` | `double` | `1.0` | Bar animation speed |
| `showMirror` | `bool` | `true` | Mirror bars (top and bottom) |

### Usage

```dart
FrequencyGlow(
  data: DataVizData(
    title: 'Your Sound',
    metrics: [
      MetricData(label: 'Hours', value: 1234),
      MetricData(label: 'Songs', value: 5678),
    ],
    total: 1234,
  ),
  theme: TemplateTheme.neon,
  barCount: 12,
  showMirror: true,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## DataVizData Reference

All data visualization templates use `DataVizData`:

```dart
DataVizData(
  title: 'Your Stats',            // Optional: section title
  subtitle: 'In Numbers',         // Optional: subtitle
  metrics: [
    MetricData(
      label: 'Hours Listened',    // Required: metric name
      value: 1234,                // Required: numeric value
      unit: 'hrs',                // Optional: unit suffix
      icon: Icons.timer,          // Optional: icon
      color: Colors.blue,         // Optional: color
      percentage: 0.75,           // Optional: percentage (0-1)
      trend: 1.0,                 // Optional: trend (-1 to 1)
    ),
  ],
  total: 1234,                    // Optional: total value
  maxValue: 2000,                 // Optional: scale max
  categories: {'Pop': 45.0},      // Optional: category breakdown
  timeSeries: {0: 100, 60: 200},  // Optional: time data
)
```

### MetricData Factories

```dart
// Percentage with % suffix
MetricData.percentage(label: 'Growth', value: 45)

// Duration in minutes (auto-formats to hours)
MetricData.minutes(label: 'Daily Average', minutes: 120)

// Simple count
MetricData.count(label: 'Songs', count: 5000)
```

---

## Theme Recommendations

| Template | Recommended Theme | Alternative |
|----------|-------------------|-------------|
| LiquidMinutes | `TemplateTheme.ocean` | `spotify` |
| OrbitalMetrics | `TemplateTheme.midnight` | `neon` |
| BinaryRain | `TemplateTheme.neon` | `midnight` |
| TheGrowthTree | `TemplateTheme.sunset` | `pastel` |
| FrequencyGlow | `TemplateTheme.neon` | `spotify` |

---

## Related

- [Templates Overview](README.md)
- [Using Templates](using-templates.md)
- [Ranking Templates](ranking-templates.md)
- [Collage Templates](collage-templates.md)
