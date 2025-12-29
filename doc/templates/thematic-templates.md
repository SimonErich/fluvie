# Thematic Templates

> **Mood and vibe scenes with distinctive aesthetics**

Thematic templates create atmosphere and emotional impact through distinctive visual styles, perfect for genre highlights, mood representations, or stylistic moments.

## Table of Contents

- [LofiWindow](#lofiwindow)
- [GlitchReality](#glitchreality)
- [Kaleidoscope](#kaleidoscope)
- [RetroPostcard](#retropostcard)
- [MinimalistBeat](#minimalistbeat)

---

## LofiWindow

> Pixel-art rainy city with condensation text

Creates a cozy, lo-fi aesthetic with a simulated rainy window view overlooking a city. Text appears as if written on foggy glass, with raindrops streaking down.

### Visual Style

- Rainy window effect
- City skyline silhouette
- Flickering window lights
- Fog/condensation overlay

### Best For

- Mood/vibe stats
- Lo-fi genre highlights
- Relaxation metrics
- Late-night listening

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `ThematicData` | **required** | Thematic content data |
| `theme` | `TemplateTheme?` | `midnight` | Visual theme |
| `rainIntensity` | `double` | `0.7` | Amount of rain (0-1) |
| `fogAmount` | `double` | `0.4` | Window fog intensity |
| `showCityLights` | `bool` | `true` | Show flickering lights |
| `seed` | `int` | `42` | Random seed for rain |

### Usage

```dart
LofiWindow(
  data: ThematicData(
    title: 'Late Night Vibes',
    subtitle: '2,345 hours',
    description: 'Your most listened genre after midnight',
    theme: 'lofi',
  ),
  rainIntensity: 0.7,
  fogAmount: 0.4,
  showCityLights: true,
).toSceneWithCrossFade()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## GlitchReality

> Digital glitch effects with fragmented visuals

Creates a cyberpunk-inspired aesthetic with digital glitches, chromatic aberration, and fragmented visuals that periodically disrupt the display.

### Visual Style

- RGB color separation
- Horizontal scan lines
- Random glitch bursts
- Fragmented text

### Best For

- Electronic/experimental genres
- Tech-themed content
- Edgy/alternative vibes
- Chaotic energy

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `ThematicData` | **required** | Thematic content data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `glitchIntensity` | `double` | `0.6` | Glitch effect strength |
| `glitchFrequency` | `double` | `0.3` | How often glitches occur |
| `showScanlines` | `bool` | `true` | CRT scanline effect |
| `chromaticAberration` | `double` | `0.02` | Color separation amount |

### Usage

```dart
GlitchReality(
  data: ThematicData(
    text: 'SYSTEM OVERRIDE',
    title: 'Electronic',
    subtitle: '1,234 hours',
    accentColor: Colors.cyan,
  ),
  theme: TemplateTheme.neon,
  glitchIntensity: 0.6,
  showScanlines: true,
).toScene()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## Kaleidoscope

> Psychedelic kaleidoscope pattern animation

Creates a mesmerizing kaleidoscope effect with rotating symmetrical patterns that morph and change colors.

### Visual Style

- Rotating symmetrical patterns
- Color-shifting gradients
- Hypnotic movement
- Central focus point

### Best For

- Psychedelic/experimental genres
- Meditation/chill content
- Abstract mood representation
- Trippy visuals

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `ThematicData` | **required** | Thematic content data |
| `theme` | `TemplateTheme?` | `sunset` | Visual theme |
| `segments` | `int` | `8` | Number of mirror segments |
| `rotationSpeed` | `double` | `0.3` | Pattern rotation speed |
| `colorShiftSpeed` | `double` | `0.5` | Color change speed |
| `complexity` | `double` | `0.7` | Pattern complexity |

### Usage

```dart
Kaleidoscope(
  data: ThematicData(
    text: 'Transcendent',
    title: 'Meditation',
    subtitle: '500 hours',
    theme: 'psychedelic',
  ),
  segments: 8,
  rotationSpeed: 0.3,
  colorShiftSpeed: 0.5,
).toSceneWithCrossFade()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## RetroPostcard

> Vintage postcard aesthetic with worn edges

Creates a nostalgic vintage postcard look with aged paper texture, worn edges, and retro typography.

### Visual Style

- Aged paper texture
- Worn/torn edges
- Vintage color grading
- Stamp and postmark details

### Best For

- Nostalgic content
- Travel memories
- Vintage/oldies genres
- Throwback themes

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `ThematicData` | **required** | Thematic content data |
| `theme` | `TemplateTheme?` | `retro` | Visual theme |
| `wearAmount` | `double` | `0.5` | Edge wear intensity |
| `showStamp` | `bool` | `true` | Show postage stamp |
| `showPostmark` | `bool` | `true` | Show circular postmark |
| `paperTint` | `Color?` | `null` | Paper color tint |

### Usage

```dart
RetroPostcard(
  data: ThematicData(
    text: 'Wish You Were Here',
    title: 'Classic Rock',
    subtitle: '2,500 plays',
    images: ['vintage_photo.jpg'],
  ),
  theme: TemplateTheme.retro,
  wearAmount: 0.5,
  showStamp: true,
  showPostmark: true,
).toScene()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## MinimalistBeat

> Clean minimal design with subtle pulse animation

Creates a sophisticated minimal aesthetic with clean typography and subtle pulsing animations synced to an implied beat.

### Visual Style

- Clean white space
- Bold typography
- Subtle pulse/beat animation
- Minimal decoration

### Best For

- Minimal/ambient genres
- Clean stat displays
- Sophisticated presentations
- Focus on content

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `ThematicData` | **required** | Thematic content data |
| `theme` | `TemplateTheme?` | `minimal` | Visual theme |
| `pulseSpeed` | `double` | `1.0` | Pulse animation speed |
| `pulseIntensity` | `double` | `0.05` | Pulse scale amount |
| `showDividers` | `bool` | `true` | Show line dividers |
| `alignment` | `TextAlign` | `center` | Text alignment |

### Usage

```dart
MinimalistBeat(
  data: ThematicData(
    text: 'Silence Speaks',
    title: 'Ambient',
    subtitle: '800 hours',
    statValue: '800',
    statLabel: 'hours of calm',
  ),
  theme: TemplateTheme.minimal,
  pulseSpeed: 1.0,
  pulseIntensity: 0.05,
  showDividers: true,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## ThematicData Reference

All thematic templates use `ThematicData`:

```dart
ThematicData(
  text: 'Your Music Journey',     // Required: main text
  title: 'The Vibe',              // Optional: title
  subtitle: '2024 Edition',       // Optional: subtitle
  description: 'Longer text...',  // Optional: description
  images: ['path1.jpg'],          // Optional: image paths
  statValue: '1,234',             // Optional: main stat
  statLabel: 'hours',             // Optional: stat label
  theme: 'lofi',                  // Optional: theme hint
  accentColor: Colors.purple,     // Optional: accent color
  metadata: {'key': value},       // Optional: extra data
)
```

---

## Theme Recommendations

| Template | Recommended Theme | Alternative |
|----------|-------------------|-------------|
| LofiWindow | `TemplateTheme.midnight` | Custom dark |
| GlitchReality | `TemplateTheme.neon` | Custom cyberpunk |
| Kaleidoscope | `TemplateTheme.sunset` | `pastel` |
| RetroPostcard | `TemplateTheme.retro` | `sunset` |
| MinimalistBeat | `TemplateTheme.minimal` | Custom light |

---

## Mood Matching Guide

| Mood/Genre | Recommended Template |
|------------|---------------------|
| Relaxed/Chill | LofiWindow |
| Electronic/Experimental | GlitchReality |
| Psychedelic/Meditation | Kaleidoscope |
| Nostalgic/Vintage | RetroPostcard |
| Minimal/Ambient | MinimalistBeat |

---

## Related

- [Templates Overview](README.md)
- [Using Templates](using-templates.md)
- [Collage Templates](collage-templates.md)
- [Conclusion Templates](conclusion-templates.md)
