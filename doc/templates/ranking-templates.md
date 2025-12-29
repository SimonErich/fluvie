# Ranking Templates

> **Display top lists and rankings with dramatic reveals**

Ranking templates are designed to showcase "Top N" lists with engaging animations that build anticipation for the #1 reveal.

## Table of Contents

- [StackClimb](#stackclimb)
- [SlotMachine](#slotmachine)
- [TheSpotlight](#thespotlight)
- [FloatingPolaroids](#floatingpolaroids)
- [PerspectiveLadder](#perspectiveladder)

---

## StackClimb

> Stacked items slide away to reveal the top spot

Creates a dramatic ranking reveal where items appear stacked on top of each other, then slide away one by one until only the winner remains, which then celebrates with a scale-up effect.

### Visual Style

- Cards stacked with slight offset
- Sequential slide-off animation
- Winner celebration with scale-up
- Confetti burst for #1

### Best For

- Top 5 lists
- Winner reveals
- Countdown rankings

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `RankingData` | **required** | Ranking content data |
| `theme` | `TemplateTheme?` | `spotify` | Visual theme |
| `slideDirection` | `StackSlideDirection` | `left` | Direction cards slide |
| `showConfetti` | `bool` | `true` | Show confetti for winner |
| `slideDelay` | `int` | `25` | Frames between slides |

### Slide Directions

```dart
StackSlideDirection.left   // Slide to the left
StackSlideDirection.right  // Slide to the right
StackSlideDirection.up     // Slide upward
StackSlideDirection.down   // Slide downward
```

### Usage

```dart
StackClimb(
  data: RankingData(
    title: 'Your Top Artists',
    items: [
      RankingItem(rank: 1, label: 'Taylor Swift', imagePath: 'taylor.jpg'),
      RankingItem(rank: 2, label: 'Drake', imagePath: 'drake.jpg'),
      RankingItem(rank: 3, label: 'The Weeknd', imagePath: 'weeknd.jpg'),
      RankingItem(rank: 4, label: 'Dua Lipa', imagePath: 'dua.jpg'),
      RankingItem(rank: 5, label: 'Bad Bunny', imagePath: 'badbunny.jpg'),
    ],
  ),
  theme: TemplateTheme.spotify,
  slideDirection: StackSlideDirection.left,
  showConfetti: true,
).toSceneWithCrossFade()
```

### Recommended Length

200 frames (6.7 seconds at 30fps)

---

## SlotMachine

> Slot machine scroll effect revealing the winner

Creates a slot machine effect where rankings spin rapidly before gradually decelerating to land on the winning entry, complete with a satisfying "click" visual effect.

### Visual Style

- Slot machine frame with highlights
- Rapid vertical scrolling
- Gradual deceleration with bounce
- Selection highlight lines

### Best For

- Single winner reveals
- Random selection effects
- Top artist/song reveals

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `RankingData` | **required** | Ranking content data |
| `theme` | `TemplateTheme?` | default | Visual theme |
| `spinCycles` | `int` | `5` | Number of scroll cycles |
| `showFrame` | `bool` | `true` | Show slot machine frame |

### Usage

```dart
SlotMachine(
  data: RankingData(
    title: 'Your #1 Song',
    items: [
      RankingItem(rank: 1, label: 'Anti-Hero', imagePath: 'antihero.jpg'),
      RankingItem(rank: 2, label: 'Flowers', imagePath: 'flowers.jpg'),
      RankingItem(rank: 3, label: 'As It Was', imagePath: 'asitwas.jpg'),
    ],
  ),
  spinCycles: 5,
  showFrame: true,
).toScene()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## TheSpotlight

> Spotlight moves across items, revealing each dramatically

Creates a dramatic reveal effect where a spotlight illuminates items one by one against a dark background, building anticipation as it moves toward the winner.

### Visual Style

- Dark background with spotlight circle
- Sequential item illumination
- Scale animation on focus
- Glow effect for winner

### Best For

- Sequential reveals
- Award presentations
- Suspenseful rankings

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `RankingData` | **required** | Ranking content data |
| `theme` | `TemplateTheme?` | default | Visual theme |
| `framesPerItem` | `int` | `25` | Time spotlight pauses on each |
| `spotlightRadius` | `double` | `150` | Size of spotlight |
| `showLabels` | `bool` | `true` | Show item labels |

### Usage

```dart
TheSpotlight(
  data: RankingData(
    title: 'Your Top 5',
    items: [
      RankingItem(rank: 1, label: 'Best Song', imagePath: 'song.jpg'),
      RankingItem(rank: 2, label: 'Second', imagePath: 'second.jpg'),
      RankingItem(rank: 3, label: 'Third', imagePath: 'third.jpg'),
      RankingItem(rank: 4, label: 'Fourth', imagePath: 'fourth.jpg'),
      RankingItem(rank: 5, label: 'Fifth', imagePath: 'fifth.jpg'),
    ],
  ),
  framesPerItem: 25,
  spotlightRadius: 150,
  showLabels: true,
).toSceneWithCrossFade()
```

### Recommended Length

Automatically calculated: `30 + (itemCount * framesPerItem) + 50`

---

## FloatingPolaroids

> Floating photos with #1 scaling up at the end

Creates a nostalgic polaroid photo effect where images float and drift around the screen with gentle rotations. At the climax, all photos fade away except the winner, which scales up to fill the screen.

### Visual Style

- Polaroid-style photo frames
- Gentle floating animation
- Rotation drift
- Winner zoom and focus

### Best For

- Photo memories
- Artist/album rankings
- Personal highlights

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `RankingData` | **required** | Ranking content data |
| `theme` | `TemplateTheme?` | `pastel` | Visual theme |
| `floatAmplitude` | `double` | `30` | Amount of float movement |
| `rotationSpeed` | `double` | `0.3` | Rotation drift speed |
| `showFlares` | `bool` | `true` | Show light flare effects |
| `seed` | `int` | `42` | Random seed for positions |

### Usage

```dart
FloatingPolaroids(
  data: RankingData(
    title: 'Your Year in Photos',
    items: [
      RankingItem(rank: 1, label: 'Summer Trip', imagePath: 'summer.jpg'),
      RankingItem(rank: 2, label: 'Concert Night', imagePath: 'concert.jpg'),
      RankingItem(rank: 3, label: 'Beach Day', imagePath: 'beach.jpg'),
      RankingItem(rank: 4, label: 'City Walk', imagePath: 'city.jpg'),
      RankingItem(rank: 5, label: 'Mountain View', imagePath: 'mountain.jpg'),
    ],
  ),
  theme: TemplateTheme.pastel,
  floatAmplitude: 30,
  showFlares: true,
).toScene()
```

### Recommended Length

210 frames (7 seconds at 30fps)

---

## PerspectiveLadder

> 3D perspective list extending into the distance

Creates a dramatic ranking display where items appear as if receding into the horizon, with the #1 item closest and most prominent. Items animate in from the vanishing point and settle into their positions.

### Visual Style

- 3D perspective effect
- Animated perspective grid background
- Items fly in from vanishing point
- Glow pulse for #1 item

### Best For

- Top 5-10 lists
- Artist/song rankings
- Achievement progressions

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `RankingData` | **required** | Ranking content data |
| `theme` | `TemplateTheme?` | `midnight` | Visual theme |
| `perspectiveDepth` | `double` | `0.004` | Depth of perspective effect |
| `rungSpacing` | `double` | `100` | Spacing between items |
| `showGlowTrails` | `bool` | `true` | Show glow trail effects |
| `staggerDelay` | `int` | `12` | Frames between item entries |

### Usage

```dart
PerspectiveLadder(
  data: RankingData(
    title: 'Top Genres',
    items: [
      RankingItem(rank: 1, label: 'Pop', value: 45, subtitle: '45%'),
      RankingItem(rank: 2, label: 'Hip-Hop', value: 28, subtitle: '28%'),
      RankingItem(rank: 3, label: 'Rock', value: 15, subtitle: '15%'),
      RankingItem(rank: 4, label: 'Electronic', value: 8, subtitle: '8%'),
      RankingItem(rank: 5, label: 'Jazz', value: 4, subtitle: '4%'),
    ],
  ),
  theme: TemplateTheme.midnight,
  showGlowTrails: true,
  staggerDelay: 12,
).toSceneWithSlide(direction: TransitionSlideDirection.up)
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## RankingData Reference

All ranking templates use `RankingData`:

```dart
RankingData(
  title: 'Top Artists',           // Optional: section title
  subtitle: 'This Year',          // Optional: subtitle
  items: [
    RankingItem(
      rank: 1,                    // Required: position (1 = first)
      label: 'Artist Name',       // Required: display text
      subtitle: '234 hours',      // Optional: secondary text
      value: 234,                 // Optional: numeric value
      imagePath: 'artist.jpg',    // Optional: item image
      metadata: {'streams': 5000}, // Optional: extra data
    ),
  ],
  isTopList: true,                // Optional: is "top N" list?
)
```

### RankingData Properties

| Property | Type | Description |
|----------|------|-------------|
| `items` | `List<RankingItem>` | All ranking items |
| `title` | `String?` | Section title |
| `subtitle` | `String?` | Section subtitle |
| `isTopList` | `bool` | Whether this is a "top N" list |
| `count` | `int` | Number of items (getter) |
| `sortedItems` | `List<RankingItem>` | Items sorted by rank (getter) |
| `topItem` | `RankingItem` | The #1 item (getter) |

---

## Theme Recommendations

| Template | Recommended Theme | Alternative |
|----------|-------------------|-------------|
| StackClimb | `TemplateTheme.spotify` | `neon` |
| SlotMachine | `TemplateTheme.neon` | `midnight` |
| TheSpotlight | `TemplateTheme.midnight` | `neon` |
| FloatingPolaroids | `TemplateTheme.pastel` | `minimal` |
| PerspectiveLadder | `TemplateTheme.midnight` | `ocean` |

---

## Related

- [Templates Overview](README.md)
- [Using Templates](using-templates.md)
- [Intro Templates](intro-templates.md)
- [DataViz Templates](data-viz-templates.md)
