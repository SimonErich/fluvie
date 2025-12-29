# Custom Fonts

> **Using custom typography in Fluvie compositions**

Custom fonts can dramatically improve the visual impact of your video compositions. This guide covers font setup, usage, and best practices.

## Table of Contents

- [Overview](#overview)
- [Adding Custom Fonts](#adding-custom-fonts)
- [Using Fonts](#using-fonts)
- [Font Variations](#font-variations)
- [Google Fonts](#google-fonts)
- [Font Loading](#font-loading)
- [Best Practices](#best-practices)

---

## Overview

Fonts in Fluvie work exactly like standard Flutter fonts. They're loaded at app startup and available throughout your composition.

### Font Types Supported

- TrueType (`.ttf`)
- OpenType (`.otf`)
- Variable fonts
- Google Fonts (via package)

---

## Adding Custom Fonts

### 1. Add Font Files to Assets

```
project/
├── assets/
│   └── fonts/
│       ├── CustomFont-Regular.ttf
│       ├── CustomFont-Bold.ttf
│       ├── CustomFont-Light.ttf
│       └── CustomFont-Italic.ttf
```

### 2. Register in pubspec.yaml

```yaml
flutter:
  fonts:
    - family: CustomFont
      fonts:
        - asset: assets/fonts/CustomFont-Regular.ttf
        - asset: assets/fonts/CustomFont-Bold.ttf
          weight: 700
        - asset: assets/fonts/CustomFont-Light.ttf
          weight: 300
        - asset: assets/fonts/CustomFont-Italic.ttf
          style: italic
```

### 3. Use in Your Composition

```dart
Text(
  'Hello World',
  style: TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 48,
    fontWeight: FontWeight.bold,
  ),
)
```

---

## Using Fonts

### Basic Text Style

```dart
Text(
  'Welcome',
  style: TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 64,
    color: Colors.white,
  ),
)
```

### With Multiple Properties

```dart
Text(
  'Your Year Wrapped',
  style: TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 72,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 4,
    height: 1.2,
    shadows: [
      Shadow(
        color: Colors.black54,
        blurRadius: 10,
        offset: Offset(2, 2),
      ),
    ],
  ),
)
```

### Text Themes

Define reusable text styles:

```dart
class AppTextStyles {
  static const title = TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 72,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  static const subtitle = TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 36,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );

  static const body = TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 24,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );
}

// Usage
Text('Title', style: AppTextStyles.title)
```

---

## Font Variations

### Weight Variants

```yaml
# pubspec.yaml
fonts:
  - family: Poppins
    fonts:
      - asset: assets/fonts/Poppins-Thin.ttf
        weight: 100
      - asset: assets/fonts/Poppins-Light.ttf
        weight: 300
      - asset: assets/fonts/Poppins-Regular.ttf
        weight: 400
      - asset: assets/fonts/Poppins-Medium.ttf
        weight: 500
      - asset: assets/fonts/Poppins-SemiBold.ttf
        weight: 600
      - asset: assets/fonts/Poppins-Bold.ttf
        weight: 700
      - asset: assets/fonts/Poppins-ExtraBold.ttf
        weight: 800
      - asset: assets/fonts/Poppins-Black.ttf
        weight: 900
```

```dart
// Use different weights
Text('Thin', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w100))
Text('Regular', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w400))
Text('Bold', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700))
Text('Black', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900))
```

### Italic Variants

```yaml
fonts:
  - family: Merriweather
    fonts:
      - asset: assets/fonts/Merriweather-Regular.ttf
      - asset: assets/fonts/Merriweather-Italic.ttf
        style: italic
      - asset: assets/fonts/Merriweather-Bold.ttf
        weight: 700
      - asset: assets/fonts/Merriweather-BoldItalic.ttf
        weight: 700
        style: italic
```

```dart
Text('Normal', style: TextStyle(fontFamily: 'Merriweather'))
Text('Italic', style: TextStyle(fontFamily: 'Merriweather', fontStyle: FontStyle.italic))
Text('Bold Italic', style: TextStyle(
  fontFamily: 'Merriweather',
  fontWeight: FontWeight.bold,
  fontStyle: FontStyle.italic,
))
```

---

## Google Fonts

### Using google_fonts Package

```yaml
# pubspec.yaml
dependencies:
  google_fonts: ^6.1.0
```

```dart
import 'package:google_fonts/google_fonts.dart';

Text(
  'Styled Text',
  style: GoogleFonts.poppins(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)
```

### Pre-loading Google Fonts

For rendering, ensure fonts are loaded before use:

```dart
// Pre-load fonts at app startup
await GoogleFonts.pendingFonts([
  GoogleFonts.poppins(),
  GoogleFonts.roboto(),
  GoogleFonts.montserrat(),
]);
```

### Bundling Google Fonts

For reliable offline rendering, bundle the fonts:

1. Download from [fonts.google.com](https://fonts.google.com)
2. Add to `assets/fonts/`
3. Register in `pubspec.yaml`

---

## Font Loading

### Ensuring Fonts Are Ready

For server-side rendering, fonts must be loaded before rendering starts:

```dart
// In your render setup
Future<void> prepareForRender() async {
  // Load custom fonts
  final fontLoader = FontLoader('CustomFont');
  fontLoader.addFont(rootBundle.load('assets/fonts/CustomFont-Regular.ttf'));
  await fontLoader.load();

  // Load Google Fonts
  await GoogleFonts.pendingFonts([
    GoogleFonts.poppins(),
  ]);
}
```

### Font Fallbacks

Define fallback fonts for missing characters:

```dart
Text(
  'Hello 你好 مرحبا',
  style: TextStyle(
    fontFamily: 'CustomFont',
    fontFamilyFallback: ['NotoSans', 'Arial'],
    fontSize: 32,
  ),
)
```

---

## Text Effects

### Gradient Text

```dart
ShaderMask(
  shaderCallback: (bounds) => LinearGradient(
    colors: [Colors.cyan, Colors.pink],
  ).createShader(bounds),
  child: Text(
    'Gradient Text',
    style: TextStyle(
      fontFamily: 'CustomFont',
      fontSize: 64,
      fontWeight: FontWeight.bold,
      color: Colors.white,  // Required for shader
    ),
  ),
)
```

### Outlined Text

```dart
Stack(
  children: [
    // Outline
    Text(
      'Outlined',
      style: TextStyle(
        fontFamily: 'CustomFont',
        fontSize: 72,
        fontWeight: FontWeight.bold,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.black,
      ),
    ),
    // Fill
    Text(
      'Outlined',
      style: TextStyle(
        fontFamily: 'CustomFont',
        fontSize: 72,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  ],
)
```

### Glowing Text

```dart
Text(
  'Glow Effect',
  style: TextStyle(
    fontFamily: 'CustomFont',
    fontSize: 64,
    color: Colors.cyan,
    shadows: [
      Shadow(color: Colors.cyan, blurRadius: 10),
      Shadow(color: Colors.cyan, blurRadius: 20),
      Shadow(color: Colors.cyan, blurRadius: 40),
    ],
  ),
)
```

---

## Best Practices

### 1. Choose Readable Fonts

For video, prioritize:
- **High contrast** between strokes
- **Clear letterforms** at various sizes
- **Consistent spacing**

Good choices: Poppins, Montserrat, Inter, Roboto

### 2. Use Appropriate Weights

| Element | Recommended Weight |
|---------|-------------------|
| Titles | Bold (700-900) |
| Subtitles | Medium (500-600) |
| Body text | Regular (400) |
| Captions | Light (300-400) |

### 3. Consider Video Compression

Thin fonts can become illegible after video compression:
- Prefer medium to bold weights
- Avoid weights under 300
- Test in final output format

### 4. Maintain Contrast

```dart
// Good: High contrast
Text('Title', style: TextStyle(color: Colors.white))  // On dark background

// Add shadow for busy backgrounds
Text(
  'Title',
  style: TextStyle(
    color: Colors.white,
    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
  ),
)
```

### 5. Consistent Typography

Use a consistent type scale throughout:

```dart
const double baseSize = 16;
const double scale = 1.25;

// Type scale
const double caption = baseSize / scale;        // 12.8
const double body = baseSize;                   // 16
const double subtitle = baseSize * scale;       // 20
const double title = baseSize * scale * scale;  // 25
const double display = title * scale;           // 31.25
```

### 6. Bundle Fonts for Reliability

Always bundle fonts in your assets rather than relying on system fonts or network loading for video rendering.

---

## Related

- [FadeText](../widgets/text/fade-text.md) - Animated text widget
- [AnimatedText](../widgets/text/animated-text.md) - Text animations
- [TypewriterText](../widgets/text/typewriter-text.md) - Typewriter effect
- [Images](images.md) - Image embedding
