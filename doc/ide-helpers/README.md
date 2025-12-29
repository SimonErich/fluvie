# IDE Helpers

Use AI assistants effectively with Fluvie by providing them the right context. This section covers using the AI reference file, IDE-specific rules, and tips for better code generation.

---

## Overview

Fluvie provides several ways to enhance AI-assisted development:

| Method | Best For | Setup Effort |
|--------|----------|--------------|
| [AI Reference File](#ai-reference-file) | Any AI tool | Low |
| [MCP Server](../mcp-agent/README.md) | Claude Desktop, Continue | Medium |
| [Cursor Rules](#cursor-rules) | Cursor IDE | Low |
| [Claude Code](#claude-code) | Claude Code CLI | Low |

---

## AI Reference File

The `FLUVIE_AI_REFERENCE.md` file contains complete Fluvie documentation in a single, AI-optimized format.

### Location

```
fluvie/doc/FLUVIE_AI_REFERENCE.md
```

### Usage

#### ChatGPT / Claude.ai

1. Upload the file as an attachment
2. Ask questions or request code generation

#### Cursor IDE

1. Add to your project root or `.cursor/` folder
2. Reference in prompts: "Using the Fluvie reference..."

#### Continue.dev

1. Add to `.continue/docs/` folder
2. Automatically included in context

#### Any AI Chat

Simply paste relevant sections or upload the file.

### What's Included

The reference file contains:

- **Quick Reference** - Import, key concepts, common patterns
- **Core Widgets** - Video, Scene, TimeConsumer
- **Layout Widgets** - VStack, VRow, VCenter, etc.
- **Animation System** - AnimatedProp, PropAnimation, Easing
- **Text Widgets** - AnimatedText, FadeText, TypewriterText
- **Media Widgets** - EmbeddedVideo, KenBurnsImage, Collage
- **Effects** - Particles, overlays, backgrounds
- **Templates** - All 30 templates with examples
- **Audio** - AudioTrack, AudioSource, BPM sync
- **Complete Examples** - Full video compositions

---

## Cursor Rules

For Cursor IDE users, create a `.cursorrules` file for Fluvie-aware code generation.

### Setup

Create `.cursorrules` in your project root:

```
You are an expert Flutter developer specializing in the Fluvie video composition library.

## Key Fluvie Concepts

- Fluvie uses FRAMES, not seconds. At 30fps: 1 second = 30 frames
- Import: `import 'package:fluvie/declarative.dart';`
- Root widget is `Video`, containing `Scene` widgets
- Animations use `AnimatedProp` with `PropAnimation`

## Widget Prefixes

Layout widgets use V prefix: VStack, VRow, VColumn, VCenter, VPadding, etc.

## Animation Patterns

Always calculate frames from seconds:
- 2 seconds at 30fps = 60 frames
- Use `AnimatedProp` for animated properties
- PropAnimation types: translate, scale, rotate, fade, combine

## Templates

Available templates by category:
- intro: TheNeonGate, DigitalMirror, TheMixtape, VortexTitle, NoiseID
- ranking: StackClimb, SlotMachine, TheSpotlight, PerspectiveLadder, FloatingPolaroids
- data_viz: OrbitalMetrics, TheGrowthTree, LiquidMinutes, FrequencyGlow, BinaryRain
- collage: TheGridShuffle, SplitPersonality, MosaicReveal, BentoRecap, TriptychScroll
- thematic: LofiWindow, GlitchReality, RetroPostcard, Kaleidoscope, MinimalistBeat
- conclusion: ParticleFarewell, TheSignature, TheSummaryPoster, TheInfinityLoop, WrappedReceipt

## Code Style

- Use const where possible
- Prefer named parameters
- Calculate durations in frames based on fps
- Use LayerStack for overlapping elements
- Use Scene with transitionIn/Out for scene transitions

## Example Scene

```dart
Scene(
  durationInFrames: 90, // 3 seconds at 30fps
  children: [
    VCenter(
      child: AnimatedProp(
        animation: PropAnimation.fade(from: 0, to: 1),
        startFrame: 0,
        endFrame: 30,
        child: Text('Hello', style: TextStyle(fontSize: 48)),
      ),
    ),
  ],
)
```

When generating Fluvie code:
1. Always include the import statement
2. Calculate frame values from desired seconds
3. Use appropriate V-prefixed layout widgets
4. Wrap animated elements in AnimatedProp
5. Consider using templates for common patterns
```

See [cursor-rules.md](cursor-rules.md) for the complete rules file.

---

## Claude Code

For Claude Code CLI users, you can reference the AI documentation directly.

### Quick Setup

Add to your project's Claude Code context:

```bash
# In your project directory
claude --context fluvie/doc/FLUVIE_AI_REFERENCE.md
```

### Using CLAUDE.md

Create a `CLAUDE.md` file in your project:

```markdown
# Project Context

This is a Fluvie video composition project.

## Documentation

Reference: doc/FLUVIE_AI_REFERENCE.md

## Key Points

- Uses Fluvie declarative API
- Frame-based timing (30fps default)
- Template-based video generation

## Common Tasks

- Generate video scenes with animations
- Use templates from the catalog
- Combine scenes with transitions
```

See [claude-code.md](claude-code.md) for detailed Claude Code integration.

---

## Example Prompts

### For Code Generation

> "Create a Fluvie scene that shows a title 'Welcome' fading in over 1 second, stays for 2 seconds, then fades out over 1 second. Use 30fps."

### For Template Selection

> "I want to create a video showing my top 5 favorite songs with album art. What Fluvie template should I use and show me an example?"

### For Learning

> "Explain how AnimatedProp works in Fluvie and show me examples of combining multiple animations"

### For Debugging

> "Why isn't my Fluvie animation playing? Here's my code: [paste code]"

---

## Tips for Better Results

### 1. Specify Frame Rate

Always mention fps when discussing timing:

> "Create a 2 second fade (60 frames at 30fps)"

### 2. Reference Templates

Templates provide proven patterns:

> "Use the StackClimb template pattern for my ranking"

### 3. Describe Visual Goals

Be specific about visual outcomes:

> "I want text to slide in from the left while scaling up from 50% to 100%"

### 4. Provide Context

Mention what you're building:

> "I'm creating a year-end review video. Generate a scene for showing listening stats."

### 5. Ask for Explanations

Understanding helps you customize:

> "Generate the code AND explain why you chose these animation timings"

---

## Related

- [MCP Agent](../mcp-agent/README.md) - Interactive MCP server
- [Cursor Rules](cursor-rules.md) - Complete .cursorrules file
- [Claude Code](claude-code.md) - CLI integration guide
