# Conclusion Templates

> **Ending scenes that wrap up your video beautifully**

Conclusion templates provide satisfying endings for your video, summarizing key stats, displaying shareable content, or creating memorable farewells.

## Table of Contents

- [TheSummaryPoster](#thesummaryposter)
- [ParticleFarewell](#particlefarewell)
- [WrappedReceipt](#wrappedreceipt)
- [TheInfinityLoop](#theinfinityloop)
- [TheSignature](#thesignature)

---

## TheSummaryPoster

> High-design poster with summary stats

Creates a shareable poster-style summary of the year with key stats, a QR code for sharing, and beautiful typography. Designed to look great as a screenshot.

### Visual Style

- Clean poster layout
- Stats in card grid
- Optional QR code
- Sparkle decorations

### Best For

- Final summaries
- Shareable content
- Year recaps

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `SummaryData` | **required** | Summary content data |
| `theme` | `TemplateTheme?` | `spotify` | Visual theme |
| `showQR` | `bool` | `true` | Show QR code |
| `showDecorations` | `bool` | `true` | Show sparkle effects |
| `layout` | `PosterLayout` | `centered` | Layout arrangement |

### Poster Layouts

```dart
PosterLayout.centered     // Stats centered in grid
PosterLayout.leftAligned  // Text left, QR right
PosterLayout.grid         // 2x2 stats grid
```

### Usage

```dart
TheSummaryPoster(
  data: SummaryData(
    title: 'Your 2024 Wrapped',
    name: 'John Doe',
    year: 2024,
    stats: {
      'Hours': '1,234',
      'Songs': '5,678',
      'Artists': '234',
      'Genres': '12',
    },
    subtitle: 'See you next year!',
    qrData: 'https://wrapped.example.com/share/123',
  ),
  theme: TemplateTheme.spotify,
  showQR: true,
  layout: PosterLayout.centered,
).toSceneWithCrossFade(fadeDuration: 30)
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## ParticleFarewell

> Explosion of particles forming farewell message

Creates a dramatic ending where particles explode outward, then converge to form a farewell message before dispersing.

### Visual Style

- Particle burst animation
- Text formation from particles
- Color-shifting particles
- Ethereal fadeout

### Best For

- Dramatic endings
- Celebratory finales
- Emotional goodbyes

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `SummaryData` | **required** | Summary content data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `particleCount` | `int` | `500` | Number of particles |
| `formationSpeed` | `double` | `1.0` | Text formation speed |
| `disperseAtEnd` | `bool` | `true` | Particles disperse at end |
| `particleColors` | `List<Color>?` | `null` | Custom particle colors |

### Usage

```dart
ParticleFarewell(
  data: SummaryData(
    title: 'Until Next Time',
    message: 'Thanks for an amazing year!',
    year: 2024,
  ),
  theme: TemplateTheme.neon,
  particleCount: 500,
  formationSpeed: 1.0,
  disperseAtEnd: true,
).toSceneWithCrossFade()
```

### Recommended Length

210 frames (7 seconds at 30fps)

---

## WrappedReceipt

> Receipt-style summary that prints out

Creates a playful receipt-style summary that "prints" line by line, mimicking a store receipt with all your stats.

### Visual Style

- Receipt paper texture
- Typewriter-style printing
- Dotted line separators
- Total at bottom

### Best For

- Playful summaries
- Detailed stat breakdowns
- Quirky endings

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `SummaryData` | **required** | Summary content data |
| `theme` | `TemplateTheme?` | `minimal` | Visual theme |
| `printSpeed` | `double` | `1.0` | Print animation speed |
| `showBarcode` | `bool` | `true` | Show barcode at bottom |
| `paperColor` | `Color?` | `null` | Receipt paper color |
| `inkColor` | `Color?` | `null` | Text/ink color |

### Usage

```dart
WrappedReceipt(
  data: SummaryData(
    title: 'YOUR RECEIPT',
    name: 'VALUED LISTENER',
    year: 2024,
    stats: {
      'HOURS LISTENED': '1,234',
      'SONGS PLAYED': '5,678',
      'NEW ARTISTS': '89',
      'PLAYLISTS MADE': '12',
    },
    message: 'THANK YOU FOR LISTENING!',
  ),
  theme: TemplateTheme.minimal,
  printSpeed: 1.0,
  showBarcode: true,
).toScene()
```

### Recommended Length

200 frames (6.7 seconds at 30fps)

---

## TheInfinityLoop

> Looping animation suggesting continuation

Creates a mesmerizing infinite loop animation symbolizing the never-ending journey, with stats displayed in the loop path.

### Visual Style

- Infinity symbol animation
- Stats along the path
- Continuous flow motion
- Glowing trail effect

### Best For

- "See you next year" themes
- Continuity messaging
- Eternal/timeless vibes

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `SummaryData` | **required** | Summary content data |
| `theme` | `TemplateTheme?` | `ocean` | Visual theme |
| `loopSpeed` | `double` | `0.5` | Animation speed |
| `glowIntensity` | `double` | `0.7` | Trail glow amount |
| `showParticles` | `bool` | `true` | Trailing particles |

### Usage

```dart
TheInfinityLoop(
  data: SummaryData(
    title: 'The Journey Continues',
    message: 'See You in 2025',
    year: 2024,
    stats: {
      'This Year': '1,234 hrs',
      'All Time': '5,678 hrs',
    },
  ),
  theme: TemplateTheme.ocean,
  loopSpeed: 0.5,
  glowIntensity: 0.7,
).toSceneWithCrossFade()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## TheSignature

> Handwritten signature animation farewell

Creates an elegant ending with a handwritten signature animation, as if personally signed by the creator or brand.

### Visual Style

- Animated signature drawing
- Elegant cursive style
- Paper texture background
- Ink pen effect

### Best For

- Personal touch endings
- Brand signatures
- Artistic farewells

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `SummaryData` | **required** | Summary content data |
| `theme` | `TemplateTheme?` | `minimal` | Visual theme |
| `drawSpeed` | `double` | `1.0` | Signature draw speed |
| `inkColor` | `Color?` | `null` | Signature ink color |
| `showUnderline` | `bool` | `true` | Draw underline flourish |
| `signatureText` | `String?` | `null` | Custom signature text |

### Usage

```dart
TheSignature(
  data: SummaryData(
    title: 'With Love',
    name: 'Your Music App',
    year: 2024,
    message: 'Thanks for the memories',
  ),
  theme: TemplateTheme.minimal,
  drawSpeed: 1.0,
  showUnderline: true,
  signatureText: 'Spotify',
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## SummaryData Reference

All conclusion templates use `SummaryData`:

```dart
SummaryData(
  title: 'That\'s a Wrap!',       // Optional: title
  subtitle: 'See You Next Year',  // Optional: subtitle
  name: 'John',                   // Optional: user name
  year: 2024,                     // Optional: year
  stats: {                        // Optional: key statistics
    'Hours': '1,234',
    'Songs': '5,678',
    'Artists': '234',
  },
  highlights: [                   // Optional: achievements
    HighlightItem(
      title: 'Top Fan',
      description: 'Top 1% of listeners',
      icon: Icons.star,
    ),
  ],
  message: 'Thanks for...',       // Optional: closing message
  ctaText: 'Share',               // Optional: button text
  shareUrl: 'https://...',        // Optional: share link
  qrData: 'https://...',          // Optional: QR code data
)
```

### HighlightItem

```dart
HighlightItem(
  title: 'Achievement Name',
  description: 'Achievement description',
  icon: Icons.star,               // Optional icon
  color: Colors.gold,             // Optional color
)
```

---

## Theme Recommendations

| Template | Recommended Theme | Alternative |
|----------|-------------------|-------------|
| TheSummaryPoster | `TemplateTheme.spotify` | `minimal` |
| ParticleFarewell | `TemplateTheme.neon` | `midnight` |
| WrappedReceipt | `TemplateTheme.minimal` | Custom paper |
| TheInfinityLoop | `TemplateTheme.ocean` | `neon` |
| TheSignature | `TemplateTheme.minimal` | `retro` |

---

## Transition Recommendations

Conclusion templates work best with longer fade-out transitions:

```dart
template.toSceneWithCrossFade(fadeDuration: 30)  // Longer fade for endings

// Or no transition out for the final scene
template.toScene(
  transitionIn: SceneTransition.crossFade(durationInFrames: 20),
  transitionOut: SceneTransition.none(),  // Final scene
)
```

---

## Related

- [Templates Overview](README.md)
- [Using Templates](using-templates.md)
- [Thematic Templates](thematic-templates.md)
- [Intro Templates](intro-templates.md)
