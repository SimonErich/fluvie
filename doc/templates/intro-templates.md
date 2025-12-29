# Intro Templates

> **Opening and identity scenes for your video**

Intro templates create dramatic opening sequences that establish the theme and identity of your video. They typically feature the year, brand, or user profile with eye-catching animations.

## Table of Contents

- [TheNeonGate](#theneongate)
- [DigitalMirror](#digitalmirror)
- [TheMixtape](#themixtape)
- [NoiseID](#noiseid)
- [VortexTitle](#vortextitle)

---

## TheNeonGate

> A central portal of glowing rings with text sliding through the center

Creates a dramatic intro effect with concentric animated rings that pulse and glow, while the title text appears to slide through the portal toward the viewer.

### Visual Style

- Glowing concentric rings that expand from center
- Pulsing/breathing animation on rings
- Text slides through "portal" with glow effects
- Sparkle particle background

### Best For

- Year intro ("Your 2024")
- Brand reveals
- Dramatic openings

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `IntroData` | **required** | Intro content data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `timing` | `TemplateTiming?` | `dramatic` | Animation timing |
| `ringCount` | `int` | `5` | Number of portal rings |
| `showParticles` | `bool` | `true` | Show sparkle background |
| `animateRotation` | `bool` | `true` | Animate ring rotation |

### Usage

```dart
TheNeonGate(
  data: IntroData(
    title: 'Your 2024',
    subtitle: 'Wrapped',
    year: 2024,
    logoPath: 'assets/logo.png',  // Optional
  ),
  theme: TemplateTheme.neon,
  timing: TemplateTiming.dramatic,
  ringCount: 5,
  showParticles: true,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## DigitalMirror

> A blurred background with a breathing profile cutout effect

Creates a mirror-like effect where the user's profile image appears as a sharp cutout against a blurred, dreamlike background. The cutout subtly pulses creating a "breathing" effect.

### Visual Style

- Blurred gradient background
- Sharp profile image cutout
- Subtle breathing/pulsing animation
- Sparkle overlay

### Best For

- Personalized intros
- Profile reveals
- Self-reflection moments

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `IntroData` | **required** | Intro content data |
| `theme` | `TemplateTheme?` | `midnight` | Visual theme |
| `blurIntensity` | `double` | `20.0` | Background blur amount |
| `showBreathing` | `bool` | `true` | Enable breathing effect |
| `profileShape` | `ProfileShape` | `circle` | Shape of profile cutout |

### Profile Shapes

```dart
ProfileShape.circle       // Circular cutout
ProfileShape.roundedSquare // Rounded square
ProfileShape.hexagon      // Hexagonal shape
```

### Usage

```dart
DigitalMirror(
  data: IntroData(
    title: 'Your Story',
    userName: 'John',
    profileImagePath: 'assets/profile.jpg',
    subtitle: 'A Year in Review',
  ),
  theme: TemplateTheme.midnight,
  profileShape: ProfileShape.circle,
  blurIntensity: 20.0,
).toScene()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## TheMixtape

> Stop-motion cassette tape animation with dynamic label

Creates a nostalgic retro effect with a spinning cassette tape where the label text is customizable. The tape reels spin to suggest playback.

### Visual Style

- Detailed cassette tape graphic
- Stop-motion frame skipping effect
- Spinning reels
- Retro grain background texture

### Best For

- Music-related content
- Retro/nostalgic themes
- Playlist reveals

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `IntroData` | **required** | Intro content data |
| `theme` | `TemplateTheme?` | `retro` | Visual theme |
| `reelSpeed` | `double` | `1.0` | Reel rotation speed |
| `stopMotion` | `bool` | `true` | Enable stop-motion effect |
| `labelColor` | `Color?` | `null` | Custom cassette label color |

### Usage

```dart
TheMixtape(
  data: IntroData(
    title: 'Your Mixtape',
    subtitle: 'Best of 2024',
    year: 2024,
  ),
  theme: TemplateTheme.retro,
  reelSpeed: 1.0,
  stopMotion: true,
  labelColor: Colors.orange,
).toSceneWithCrossFade()
```

### Recommended Length

150 frames (5 seconds at 30fps)

---

## NoiseID

> Grunge texture with ink-bleed stamp effect title

Creates a raw, textured aesthetic where the title appears to be stamped or printed onto a distressed background with organic ink bleeding edges.

### Visual Style

- Animated noise/grain texture
- Distressed overlay scratches
- Stamp "impact" animation
- Ink bleed spreading effect

### Best For

- Alternative/indie vibes
- Grunge aesthetics
- Underground/authentic feel

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `IntroData` | **required** | Intro content data |
| `theme` | `TemplateTheme?` | `minimal` | Visual theme |
| `noiseIntensity` | `double` | `0.3` | Background noise amount (0-1) |
| `animateInkBleed` | `bool` | `true` | Animate ink spreading |
| `stampColor` | `Color?` | `null` | Custom stamp color |

### Usage

```dart
NoiseID(
  data: IntroData(
    title: 'UNDERGROUND',
    subtitle: '2024 Sounds',
    year: 2024,
  ),
  theme: TemplateTheme.minimal,
  noiseIntensity: 0.3,
  animateInkBleed: true,
).toScene()
```

### Recommended Length

120 frames (4 seconds at 30fps)

---

## VortexTitle

> Typography spirals in from corners, converging at center

Creates a dynamic vortex effect where text characters or words spin inward from different corners, creating a hypnotic convergence effect.

### Visual Style

- Individual letters spiral inward
- Decorative vortex lines in background
- Glowing text with shadows
- Sparkle particle trails

### Best For

- Dramatic title reveals
- Word emphasis
- Energy-filled intros

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `data` | `IntroData` | **required** | Intro content data |
| `theme` | `TemplateTheme?` | `neon` | Visual theme |
| `animateLetters` | `bool` | `true` | Animate individual letters |
| `spiralSpeed` | `double` | `1.0` | Speed of spiral rotation |
| `spiralRotations` | `double` | `2.0` | Number of rotations before settling |
| `showTrails` | `bool` | `true` | Show particle trail effects |

### Usage

```dart
VortexTitle(
  data: IntroData(
    title: 'WRAPPED',
    subtitle: 'Your Year',
    year: 2024,
  ),
  theme: TemplateTheme.neon,
  animateLetters: true,
  spiralRotations: 2.0,
  showTrails: true,
).toSceneWithCrossFade()
```

### Recommended Length

180 frames (6 seconds at 30fps)

---

## IntroData Reference

All intro templates use `IntroData`:

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

---

## Theme Recommendations

| Template | Recommended Theme | Alternative |
|----------|-------------------|-------------|
| TheNeonGate | `TemplateTheme.neon` | `spotify` |
| DigitalMirror | `TemplateTheme.midnight` | `ocean` |
| TheMixtape | `TemplateTheme.retro` | `sunset` |
| NoiseID | `TemplateTheme.minimal` | Custom dark |
| VortexTitle | `TemplateTheme.neon` | `spotify` |

---

## Related

- [Templates Overview](README.md)
- [Using Templates](using-templates.md)
- [Ranking Templates](ranking-templates.md)
