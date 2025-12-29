# Collage Templates

> **Photo grids and image arrangements**

Collage templates display multiple images in creative arrangements, perfect for showcasing album art, photos, or memories.

## Table of Contents

- [TheGridShuffle](#thegridshuffle)
- [MosaicReveal](#mosaicreveal)
- [BentoRecap](#bentorecap)
- [TriptychScroll](#triptychscroll)
- [SplitPersonality](#splitpersonality)

---

## TheGridShuffle

> 3x3 grid with shuffling images that settle

Creates an exciting reveal where images swap positions rapidly like a shuffle animation before settling into their final grid arrangement.

### Visual Style

- 3x3 (or custom) grid layout
- Rapid position swapping
- Cards fly in from bottom
- Smooth settle animation

### Best For

- Top 9 grid
- Album art displays
- Photo collages

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `CollageData` | **required** | Collage content data |
| `theme` | `TemplateTheme?` | `spotify` | Visual theme |
| `gridSize` | `int` | `3` | Grid dimensions (NxN) |
| `shuffleDuration` | `int` | `60` | Shuffle phase frames |
| `cellGap` | `double` | `8` | Gap between cells |
| `seed` | `int` | `42` | Random seed for shuffle |

### Usage

```dart
TheGridShuffle(
  data: CollageData(
    title: 'Your Top Albums',
    subtitle: '2024 Collection',
    images: [
      'album1.jpg', 'album2.jpg', 'album3.jpg',
      'album4.jpg', 'album5.jpg', 'album6.jpg',
      'album7.jpg', 'album8.jpg', 'album9.jpg',
    ],
  ),
  gridSize: 3,
  shuffleDuration: 60,
  cellGap: 8,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## MosaicReveal

> Mosaic tiles flip to reveal images

Creates a puzzle-like effect where blank tiles flip over one by one to reveal the underlying image collage.

### Visual Style

- Grid of square tiles
- Flip reveal animation
- Staggered tile reveals
- Glowing highlight effect

### Best For

- Reveal sequences
- Photo memories
- Grid galleries

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `CollageData` | **required** | Collage content data |
| `theme` | `TemplateTheme?` | `midnight` | Visual theme |
| `tileCount` | `int` | `4` | Tiles per side (NxN) |
| `revealPattern` | `RevealPattern` | `spiral` | Order of reveal |
| `flipDuration` | `int` | `15` | Frames per flip |

### Reveal Patterns

```dart
RevealPattern.spiral    // Spiral from center
RevealPattern.random    // Random order
RevealPattern.rows      // Row by row
RevealPattern.diagonal  // Diagonal sweep
```

### Usage

```dart
MosaicReveal(
  data: CollageData(
    title: 'Memories',
    images: [
      'photo1.jpg', 'photo2.jpg', 'photo3.jpg', 'photo4.jpg',
      'photo5.jpg', 'photo6.jpg', 'photo7.jpg', 'photo8.jpg',
      'photo9.jpg', 'photo10.jpg', 'photo11.jpg', 'photo12.jpg',
      'photo13.jpg', 'photo14.jpg', 'photo15.jpg', 'photo16.jpg',
    ],
  ),
  tileCount: 4,
  revealPattern: RevealPattern.spiral,
).toScene()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## BentoRecap

> Japanese bento box-style layout with varied sizes

Creates an asymmetric grid layout inspired by bento boxes, with one featured large image and several smaller ones.

### Visual Style

- Asymmetric grid layout
- One featured large cell
- Mixed sizes create visual interest
- Smooth entry animations

### Best For

- Featured + supporting images
- Album highlights
- Mixed content displays

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `CollageData` | **required** | Collage content data |
| `theme` | `TemplateTheme?` | `minimal` | Visual theme |
| `layout` | `BentoLayout` | `standard` | Layout arrangement |
| `gap` | `double` | `12` | Gap between cells |
| `borderRadius` | `double` | `16` | Cell corner radius |

### Bento Layouts

```dart
BentoLayout.standard    // Large left, small right
BentoLayout.inverted    // Large right, small left
BentoLayout.topHeavy    // Large top, small bottom
BentoLayout.bottomHeavy // Large bottom, small top
```

### Usage

```dart
BentoRecap(
  data: CollageData(
    title: 'Your Highlights',
    images: [
      'featured.jpg',   // Large image
      'small1.jpg', 'small2.jpg', 'small3.jpg',
      'small4.jpg', 'small5.jpg',
    ],
    featuredIndex: 0,
  ),
  layout: BentoLayout.standard,
  gap: 12,
  borderRadius: 16,
).toSceneWithSlide(direction: TransitionSlideDirection.up)
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## TriptychScroll

> Three-panel horizontal scroll reveal

Creates a cinematic triptych effect with three vertical panels that scroll in from different directions.

### Visual Style

- Three vertical panels
- Parallax scroll effect
- Images slide into place
- Elegant transitions

### Best For

- Three featured images
- Before/during/after sequences
- Cinematic reveals

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `CollageData` | **required** | Collage content data |
| `theme` | `TemplateTheme?` | `minimal` | Visual theme |
| `panelGap` | `double` | `20` | Gap between panels |
| `parallaxIntensity` | `double` | `0.3` | Parallax effect amount |
| `showCaptions` | `bool` | `true` | Show image captions |

### Usage

```dart
TriptychScroll(
  data: CollageData(
    title: 'Your Journey',
    images: ['past.jpg', 'present.jpg', 'future.jpg'],
    captions: ['Then', 'Now', 'Next'],
  ),
  panelGap: 20,
  parallaxIntensity: 0.3,
  showCaptions: true,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## SplitPersonality

> Split-screen comparison layout

Creates a dynamic split-screen effect showing contrasting or related images side by side with animated divider.

### Visual Style

- Two-panel split layout
- Animated center divider
- Zoom/pan on each half
- Comparison labels

### Best For

- Before/after comparisons
- Genre contrasts
- Day vs night themes

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `CollageData` | **required** | Collage content data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `splitDirection` | `SplitDirection` | `vertical` | Split orientation |
| `animateDivider` | `bool` | `true` | Animate the divider |
| `showLabels` | `bool` | `true` | Show side labels |

### Split Directions

```dart
SplitDirection.vertical    // Left/right split
SplitDirection.horizontal  // Top/bottom split
SplitDirection.diagonal    // Diagonal split
```

### Usage

```dart
SplitPersonality(
  data: CollageData(
    title: 'Your Moods',
    images: ['happy.jpg', 'chill.jpg'],
    captions: ['Upbeat', 'Relaxed'],
  ),
  splitDirection: SplitDirection.vertical,
  animateDivider: true,
  showLabels: true,
).toScene()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## CollageData Reference

All collage templates use `CollageData`:

```dart
CollageData(
  title: 'Your Moments',          // Optional: section title
  subtitle: '2024 Gallery',       // Optional: subtitle
  description: 'A year in...',    // Optional: description
  images: [                       // Required: image paths
    'assets/photo1.jpg',
    'assets/photo2.jpg',
    'assets/photo3.jpg',
  ],
  captions: ['One', 'Two', 'Three'], // Optional: per-image captions
  featuredIndex: 0,               // Optional: featured image index
  layout: TemplateCollageLayout.grid, // Optional: layout hint
  stats: {'Photos': 100},         // Optional: statistics
)
```

### Layout Hints

```dart
TemplateCollageLayout.grid      // Standard grid
TemplateCollageLayout.masonry   // Pinterest-style
TemplateCollageLayout.featured  // One large + thumbnails
TemplateCollageLayout.strip     // Horizontal scroll
TemplateCollageLayout.diagonal  // Diagonal arrangement
```

---

## Image Recommendations

| Grid Size | Images Needed | Aspect Ratio |
|-----------|---------------|--------------|
| 3x3 | 9 images | Square (1:1) |
| 4x4 | 16 images | Square (1:1) |
| Bento | 5-6 images | Mixed |
| Triptych | 3 images | Portrait (3:4) |
| Split | 2 images | Depends on split |

---

## Theme Recommendations

| Template | Recommended Theme | Alternative |
|----------|-------------------|-------------|
| TheGridShuffle | `TemplateTheme.spotify` | `neon` |
| MosaicReveal | `TemplateTheme.midnight` | `minimal` |
| BentoRecap | `TemplateTheme.minimal` | `pastel` |
| TriptychScroll | `TemplateTheme.minimal` | `ocean` |
| SplitPersonality | `TemplateTheme.neon` | `spotify` |

---

## Related

- [Templates Overview](README.md)
- [Using Templates](using-templates.md)
- [DataViz Templates](data-viz-templates.md)
- [Thematic Templates](thematic-templates.md)
