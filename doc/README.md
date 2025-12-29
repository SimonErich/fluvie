# Fluvie Documentation

> **Create stunning videos programmatically with Flutter**

Fluvie is a powerful Flutter library that lets you compose and render videos using familiar Flutter widgets. Whether you're building Spotify Wrapped-style year reviews, animated social media content, or automated video generation pipelines, Fluvie gives you the tools to create professional videos entirely in code.

## Quick Example

```dart
import 'package:fluvie/declarative.dart';

Video(
  fps: 30,
  width: 1920,
  height: 1080,
  scenes: [
    Scene(
      durationInFrames: 90, // 3 seconds at 30fps
      background: Background.gradient(
        colors: {0: Colors.purple, 90: Colors.blue},
      ),
      children: [
        VCenter(
          child: AnimatedText.slideUpFade(
            'Hello, Fluvie!',
            style: TextStyle(fontSize: 72, color: Colors.white),
          ),
        ),
      ],
    ),
  ],
)
```

---

## Table of Contents

- [Getting Started](#getting-started)
- [Core Concepts](#core-concepts)
- [Tutorials](#tutorials)
- [Widget Reference](#widget-reference)
- [Features](#features)
- [Advanced Topics](#advanced-topics)
- [Examples](#examples)
- [Contributing](#contributing)

---

## Getting Started

New to Fluvie? Start here:

| Guide | Description |
|-------|-------------|
| [Installation](getting-started/installation.md) | Add Fluvie to your project |
| [FFmpeg Setup](getting-started/ffmpeg-setup.md) | Configure video encoding for your platform |
| [First Video](getting-started/first-video.md) | Create your first animated video |

**Platform-specific setup:**
- [Linux](platform_setup/linux.md) | [macOS](platform_setup/macos.md) | [Windows](platform_setup/windows.md) | [Web](platform_setup/web.md) | [Mobile](platform_setup/mobile.md)

---

## Core Concepts

Understand how Fluvie works under the hood:

| Topic | Description |
|-------|-------------|
| [Architecture](concept/architecture.md) | The dual-engine model (Flutter + FFmpeg) |
| [Frame-Based Animation](concept/frame-based-animation.md) | Why frames matter for video |
| [Rendering Pipeline](concept/rendering-pipeline.md) | How widgets become video |
| [Preview vs Render Mode](concept/two-modes.md) | Interactive development vs final export |

---

## Tutorials

Step-by-step guides to build complete videos:

| Tutorial | What You'll Build |
|----------|-------------------|
| [Simple Animation](tutorials/simple-animation.md) | Image, animated text, and background music |
| [Advanced Composition](tutorials/advanced-composition.md) | Multi-scene video with transitions, effects, and embedded video |

---

## Widget Reference

### Core Widgets
The building blocks of every Fluvie video:

| Widget | Purpose |
|--------|---------|
| [Video](widgets/core/video.md) | Declarative composition root (high-level API) |
| [VideoComposition](widgets/core/video-composition.md) | Low-level composition root |
| [Scene](widgets/core/scene.md) | Time-bounded section of video |
| [Sequence](widgets/core/sequence.md) | Basic timing container |
| [TimeConsumer](widgets/core/time-consumer.md) | Frame-based animation driver |

### Layout Widgets
Video-aware layout with timing and fade support:

| Widget | Purpose |
|--------|---------|
| [LayerStack](widgets/layout/layer-stack.md) | Z-indexed layer composition |
| [Layer](widgets/layout/layer.md) | Individual layer with visibility timing |
| [VStack](widgets/layout/v-stack.md) | Video-aware Stack |
| [VColumn](widgets/layout/v-column.md) | Column with stagger animation support |
| [VRow](widgets/layout/v-row.md) | Row with stagger animation support |
| [VCenter](widgets/layout/v-center.md) | Centered content with timing |
| [VPadding](widgets/layout/v-padding.md) | Padded content with timing |
| [VSizedBox](widgets/layout/v-sized-box.md) | Sized box with timing |
| [VPositioned](widgets/layout/v-positioned.md) | Positioned elements with hero transitions |

### Audio Widgets
Add music, sound effects, and audio-reactive features:

| Widget | Purpose |
|--------|---------|
| [AudioTrack](widgets/audio/audio-track.md) | Precise audio timing and sync |
| [AudioSource](widgets/audio/audio-source.md) | Audio file references |
| [BackgroundAudio](widgets/audio/background-audio.md) | Full-video background music |
| [AudioReactive](widgets/audio/audio-reactive.md) | BPM and frequency analysis |

### Text Widgets
Animated typography:

| Widget | Purpose |
|--------|---------|
| [FadeText](widgets/text/fade-text.md) | Text with opacity support |
| [AnimatedText](widgets/text/animated-text.md) | Pre-built text animations |
| [TypewriterText](widgets/text/typewriter-text.md) | Character-by-character reveal |
| [CounterText](widgets/text/counter-text.md) | Animated number counting |

### Media Widgets
Embed images and videos:

| Widget | Purpose |
|--------|---------|
| [EmbeddedVideo](widgets/media/embedded-video.md) | Video-in-video with frame sync |
| [VideoSequence](widgets/media/video-sequence.md) | External video files |
| [Collage](widgets/media/collage.md) | Multi-element layouts |

---

## Features

### [Animations](animations/README.md)
Powerful animation system with presets and customization:
- [PropAnimation](animations/prop-animation.md) - Transform, scale, rotate, fade
- [Entry Animations](animations/entry-animations.md) - Dramatic entrance effects
- [Stagger Config](animations/stagger-config.md) - Sequenced child animations
- [Interpolate](animations/interpolate.md) - Keyframe-based values
- [Easing Curves](animations/easing.md) - Smooth motion curves

### [Effects](effects/README.md)
Visual enhancements and atmosphere:
- [Particle Effects](effects/particle-effect.md) - Sparkles, confetti, rain
- [Effect Overlays](effects/effect-overlay.md) - Vignette, grain, scanlines
- [Backgrounds](effects/backgrounds.md) - Gradients and solid colors
- [Transitions](effects/transitions.md) - Scene-to-scene effects

### [Helper Widgets](helpers/README.md)
Ready-made components for common patterns:
- [PolaroidFrame](helpers/polaroid-frame.md) - Photo frame styling
- [PhotoCard](helpers/photo-card.md) - Card-style photos
- [StatCard](helpers/stat-card.md) - Animated statistics
- [FloatingElement](helpers/floating-element.md) - Ambient motion
- [KenBurnsImage](helpers/ken-burns-image.md) - Zoom and pan effect

### [Templates](templates/README.md)
30 production-ready templates across 6 categories:
- [Intro Templates](templates/intro-templates.md) - Opening sequences
- [Ranking Templates](templates/ranking-templates.md) - Top lists
- [Data Viz Templates](templates/data-viz-templates.md) - Statistics displays
- [Collage Templates](templates/collage-templates.md) - Image layouts
- [Thematic Templates](templates/thematic-templates.md) - Mood pieces
- [Conclusion Templates](templates/conclusion-templates.md) - Closing scenes

### [Embedding Media](embedding/README.md)
Include external assets in your videos:
- [Images](embedding/images.md) - Photos and graphics
- [Videos](embedding/videos.md) - Video clips and loops
- [Audio](embedding/audio.md) - Music and sound effects
- [Fonts](embedding/fonts.md) - Custom typography

---

## Advanced Topics

| Topic | Description |
|-------|-------------|
| [Encoding Settings](advanced/encoding-settings.md) | Quality, format, and codec options |
| [Sync Anchors](advanced/sync-anchors.md) | Precise audio-visual synchronization |
| [Custom Render Pipeline](advanced/custom-render-pipeline.md) | Advanced rendering control |
| [Frame Extraction](advanced/frame-extraction.md) | Extract frames from videos |
| [Performance Tips](advanced/performance-tips.md) | Optimization techniques |

### Special Modes
- [Server-Only Mode](ONLY_SERVER_MODE.md) - Rendering without a Flutter UI

---

## Extending Fluvie

Build your own animations, effects, and templates:

| Guide | Description |
|-------|-------------|
| [Custom Animations](extending/custom-animations.md) | Create PropAnimation subclasses |
| [Custom Effects](extending/custom-effects.md) | Build visual effects |
| [Custom Templates](extending/custom-templates.md) | Design reusable templates |
| [Custom FFmpeg Provider](extending/custom-ffmpeg-provider.md) | Platform-specific encoding |

---

## Examples

Explore working examples in the `/example` directory:

| Example | Description |
|---------|-------------|
| [Simple Animation](../example/lib/gallery/examples/example_1_simple_animation.dart) | Basic shapes and motion |
| [Text Overlay](../example/lib/gallery/examples/example_2_text_overlay.dart) | Text on images |
| [Image Slideshow](../example/lib/gallery/examples/example_3_image_slideshow.dart) | Photo transitions |
| [Layered Composition](../example/lib/gallery/examples/example_6_layered_composition.dart) | Complex layering |
| [Animated Gradient](../example/lib/gallery/examples/example_7_animated_gradient.dart) | Color animations |
| [Year in Review](../example/lib/gallery/examples/example_year_review.dart) | Complete Spotify Wrapped-style video |
| [FlutterVienna Review](../example/lib/gallery/examples/example_flutter_vie_review.dart) | Advanced production example |

Run the example app:
```bash
cd example
flutter run
```

---

## Contributing

We welcome contributions! See our guides:

| Guide | Description |
|-------|-------------|
| [Contributing Overview](contributing/README.md) | How to help |
| [Development Setup](contributing/development-setup.md) | Local environment |
| [Testing Guide](contributing/testing.md) | Writing tests |
| [Code Style](contributing/code-style.md) | Formatting standards |
| [Getting Support](contributing/support.md) | Issues and help |

---

## License

Fluvie is released under the MIT License. See [LICENSE](../LICENSE) for details.

---

## AI & IDE Integration

Use AI assistants effectively with Fluvie:

| Resource | Description |
|----------|-------------|
| [AI Reference File](FLUVIE_AI_REFERENCE.md) | Complete documentation in one AI-optimized file |
| [MCP Server](mcp-agent/README.md) | Model Context Protocol server for AI tools |
| [IDE Helpers](ide-helpers/README.md) | Cursor rules, Claude Code, and editor integration |

**Quick Links:**
- [MCP Setup](mcp-agent/setup.md) - Self-host the MCP server
- [IDE Integration](mcp-agent/ide-integration.md) - Configure Claude Desktop, VS Code, etc.
- [Cursor Rules](ide-helpers/cursor-rules.md) - Rules file for Cursor IDE

---

## Links

- [GitHub Repository](https://github.com/simonerich/fluvie)
- [Pub.dev Package](https://pub.dev/packages/fluvie)
- [Issue Tracker](https://github.com/simonerich/fluvie/issues)
- [MCP Server](https://mcp.fluvie.at) - AI documentation server
