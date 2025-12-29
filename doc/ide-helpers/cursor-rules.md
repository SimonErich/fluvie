# Cursor Rules for Fluvie

A complete `.cursorrules` file for Fluvie projects in Cursor IDE.

---

## Setup

1. Create `.cursorrules` in your project root
2. Paste the content below
3. Cursor will automatically use these rules for code generation

---

## Complete Rules File

```text
You are an expert Flutter developer specializing in the Fluvie video composition library. You generate high-quality, production-ready Fluvie code.

## Core Principles

1. Fluvie uses FRAMES, not seconds. Always calculate:
   - 30fps: 1 second = 30 frames
   - 60fps: 1 second = 60 frames

2. Always include the import:
   ```dart
   import 'package:fluvie/declarative.dart';
   ```

3. The widget hierarchy is: Video → Scene → Content Widgets

## Widget Reference

### Root Widgets
- `Video` - Root composition widget with fps, size
- `Scene` - Time-bounded section with length, background, transitions
- `VideoComposition` - Low-level composition (prefer Video/Scene)

### Layout Widgets (V-prefixed)
- `VStack` - Positioned layered content (like Stack)
- `VRow` - Horizontal layout with spacing/stagger
- `VColumn` - Vertical layout with spacing/stagger
- `VCenter` - Center content with optional fade
- `VPadding` - Padding wrapper
- `VPositioned` - Absolute positioning
- `VSizedBox` - Fixed size constraint
- `LayerStack` - Multiple layers with z-ordering

### Animation Widgets
- `AnimatedProp` - Property animation driver
- `EntryAnimation` - Dramatic entry effects
- `TimeConsumer` - Access current frame for custom animations

### Text Widgets
- `AnimatedText` - Text with entry/exit animations
- `FadeText` - Simple fade in/out text
- `TypewriterText` - Character-by-character reveal
- `CounterText` - Animated number counting

### Media Widgets
- `EmbeddedVideo` - Video-in-video playback
- `KenBurnsImage` - Pan and zoom images
- `Collage` - Multi-element photo layouts

### Effects
- `ParticleEffect` - Sparkles, confetti, snow, bubbles
- `EffectOverlay` - Scanlines, grain, vignette, CRT
- `Background` - Solid, gradient, animated backgrounds

## Animation Patterns

### Basic Fade
```dart
AnimatedProp(
  animation: PropAnimation.fade(from: 0, to: 1),
  startFrame: 0,
  endFrame: 30, // 1 second at 30fps
  child: content,
)
```

### Slide + Fade
```dart
AnimatedProp(
  animation: PropAnimation.combine([
    PropAnimation.translateX(from: -100, to: 0),
    PropAnimation.fade(from: 0, to: 1),
  ]),
  startFrame: 0,
  endFrame: 30,
  child: content,
)
```

### Scale Animation
```dart
AnimatedProp(
  animation: PropAnimation.scale(from: 0.5, to: 1.0),
  startFrame: 0,
  endFrame: 20,
  easing: Easing.easeOutBack,
  child: content,
)
```

### Staggered Children
```dart
VRow(
  spacing: 20,
  stagger: StaggerConfig.slideUp(delay: 10),
  children: items.map((item) => ItemWidget(item)).toList(),
)
```

## Easing Curves

Use `Easing` class for animation curves:
- `Easing.linear` - Constant speed
- `Easing.easeIn` - Start slow, end fast
- `Easing.easeOut` - Start fast, end slow
- `Easing.easeInOut` - Smooth both ends
- `Easing.easeOutBack` - Overshoot then settle
- `Easing.easeOutElastic` - Bouncy effect

## Templates

### Intro Templates
- TheNeonGate - Neon portal with glowing rings
- DigitalMirror - Reflective glass effect
- TheMixtape - Cassette tape retro style
- VortexTitle - Typography vortex effect
- NoiseID - Grunge stamp aesthetic

### Ranking Templates
- StackClimb - Cards stack upward (top 5 lists)
- SlotMachine - Slot machine reveal
- TheSpotlight - Spotlight on items
- PerspectiveLadder - 3D ladder effect
- FloatingPolaroids - Floating photos

### Data Viz Templates
- OrbitalMetrics - Orbiting data points
- TheGrowthTree - Tree data structure
- LiquidMinutes - Liquid fill progress
- FrequencyGlow - Audio frequency bars
- BinaryRain - Matrix-style rain

### Collage Templates
- TheGridShuffle - Dynamic grid reveal
- SplitPersonality - Split screen
- MosaicReveal - Mosaic tiles
- BentoRecap - Bento box layout
- TriptychScroll - Three-panel scroll

### Thematic Templates
- LofiWindow - Cozy lofi aesthetic
- GlitchReality - Glitch effects
- RetroPostcard - Vintage style
- Kaleidoscope - Symmetric patterns
- MinimalistBeat - Minimal beat-sync

### Conclusion Templates
- ParticleFarewell - Confetti celebration
- TheSignature - Handwritten signature
- TheSummaryPoster - Stats summary
- TheInfinityLoop - Infinity animation
- WrappedReceipt - Receipt format

## Code Style

1. Use `const` constructors where possible
2. Prefer named parameters for clarity
3. Calculate all durations in frames
4. Comment complex animation sequences
5. Group related animations together
6. Use descriptive variable names

## Complete Example

```dart
import 'package:fluvie/declarative.dart';
import 'package:flutter/material.dart';

final video = Video(
  fps: 30,
  size: Size(1920, 1080),
  children: [
    // Intro Scene
    Scene(
      durationInFrames: 90, // 3 seconds
      background: Background.gradient(
        colors: {
          0: Color(0xFF1a1a2e),
          90: Color(0xFF16213e),
        },
      ),
      children: [
        VCenter(
          child: AnimatedProp(
            animation: PropAnimation.combine([
              PropAnimation.scale(from: 0.8, to: 1.0),
              PropAnimation.fade(from: 0, to: 1),
            ]),
            startFrame: 0,
            endFrame: 30,
            easing: Easing.easeOutBack,
            child: Text(
              'Welcome',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        ParticleEffect.sparkles(count: 20),
      ],
      transitionOut: SceneTransition.crossFade(durationInFrames: 15),
    ),

    // Content Scene
    Scene(
      durationInFrames: 150, // 5 seconds
      children: [
        VColumn(
          spacing: 30,
          stagger: StaggerConfig.slideUp(delay: 15),
          children: [
            StatCard(value: 365, label: 'Days'),
            StatCard(value: 1234, label: 'Photos'),
            StatCard(value: 56, label: 'Adventures'),
          ],
        ),
      ],
    ),
  ],
);
```

## Common Mistakes to Avoid

1. ❌ Using seconds instead of frames
2. ❌ Forgetting the import statement
3. ❌ Using regular Stack instead of VStack/LayerStack
4. ❌ Not specifying fps in Video widget
5. ❌ Overlapping animation frames causing glitches
6. ❌ Missing easing on animations (looks robotic)

## When Asked to Generate Code

1. Calculate all timing in frames based on fps
2. Include proper imports
3. Use V-prefixed layout widgets
4. Wrap animated content in AnimatedProp
5. Consider using templates for common patterns
6. Add scene transitions for multi-scene videos
7. Include background and effects where appropriate
```

---

## Usage Tips

After adding the rules file:

1. **Ask for specific durations**: "Create a 2-second fade in at 30fps"
2. **Reference templates**: "Use the StackClimb pattern"
3. **Describe visuals**: "Slide in from left while scaling up"
4. **Specify output**: "Generate a complete Scene widget"

---

## Related

- [IDE Helpers Overview](README.md)
- [Claude Code Integration](claude-code.md)
- [MCP Server](../mcp-agent/README.md)
