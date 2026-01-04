# Getting Started with Fluvie + MCP (Vibecoding)

> **Create videos by describing what you want in natural language**

This guide shows you how to use Fluvie with AI assistants like Claude, Cursor, or VS Code with MCP (Model Context Protocol) integration.

## Table of Contents

- [What is Fluvie MCP?](#what-is-fluvie-mcp)
- [Step 1: Set Up MCP Server](#step-1-set-up-mcp-server)
- [Step 2: Create Your Project](#step-2-create-your-project)
- [Step 3: Prompt Effectively](#step-3-prompt-effectively)
- [Step 4: Preview and Export](#step-4-preview-and-export)
- [Example Prompts](#example-prompts)

---

## What is Fluvie MCP?

Fluvie MCP Server provides AI assistants with:
- **Documentation search** - Find relevant widgets and APIs
- **Code generation** - Generate complete video compositions
- **Template suggestions** - Get template recommendations for your use case
- **Widget reference** - Access detailed widget documentation

The MCP server is hosted at `https://mcp.fluvie.dev/mcp` and works with any MCP-compatible AI assistant.

---

## Step 1: Set Up MCP Server

### For Claude Desktop / Claude Code

Add to your `claude_desktop_config.json` or MCP settings:

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.dev/mcp",
      "transport": "http"
    }
  }
}
```

### For Cursor

Add to your Cursor MCP settings:

```json
{
  "mcpServers": {
    "fluvie": {
      "url": "https://mcp.fluvie.dev/mcp",
      "transport": "http"
    }
  }
}
```

### For VS Code with MCP Extension

Configure in your MCP extension settings with the server URL: `https://mcp.fluvie.dev/mcp`

---

## Step 2: Create Your Project

### Quick Setup

```bash
# Create a new Flutter project
flutter create my_video_app
cd my_video_app

# Add Fluvie dependency
flutter pub add fluvie
```

### Install FFmpeg

FFmpeg is required for video encoding:

```bash
# macOS
brew install ffmpeg

# Linux (Ubuntu/Debian)
sudo apt install ffmpeg

# Windows
# Download from ffmpeg.org and add to PATH
```

---

## Step 3: Prompt Effectively

### Basic Prompting Pattern

When working with AI, use this structure:

```
Create a Fluvie video with:
- [Describe content/scenes]
- [Specify dimensions: 1080x1920 for vertical, 1920x1080 for horizontal]
- [Mention any special effects or animations]
```

### Good Prompt Examples

**Simple intro video:**
```
Create a Fluvie video with a title "Hello World" that slides up with a fade effect,
on a gradient background from dark blue to purple. Make it 1080x1920 vertical format.
```

**Multi-scene video:**
```
Create a Fluvie video with 3 scenes:
1. Intro with animated title "2024 Wrapped"
2. Stats scene showing numbers counting up
3. Outro with "Thanks for watching"
Use smooth transitions between scenes. Vertical format 1080x1920.
```

**With specific styling:**
```
Create a Fluvie video with:
- Neon-style title text
- Particle effects in the background
- Dark theme with pink/purple accent colors
- 4 seconds total duration at 30fps
```

### What to Ask For

- **Preview setup**: "Include the VideoPreview widget so I can test it"
- **Export code**: "Show me how to export this video"
- **Template usage**: "Use a template for a year-in-review intro"

---

## Step 4: Preview and Export

The AI should generate code that looks like this:

### main.dart

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/declarative.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Video',
      theme: ThemeData.dark(),
      home: const VideoPage(),
    );
  }
}

class VideoPage extends StatelessWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Video')),
      body: VideoPreview(
        video: const MyVideo(),
        showControls: true,
        showExportButton: true,
      ),
    );
  }
}
```

### my_video.dart

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/declarative.dart';

class MyVideo extends StatelessWidget {
  const MyVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 1080,
      height: 1920,
      defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
      scenes: [
        Scene(
          durationInFrames: 120,
          background: Background.gradient(
            colors: {
              0: const Color(0xFF1a1a2e),
              120: const Color(0xFF0f3460),
            },
          ),
          children: [
            VCenter(
              child: AnimatedText.slideUpFade(
                'Hello World',
                duration: 30,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

### Run and Preview

```bash
flutter run
```

The `VideoPreview` widget provides:
- **Play/Pause** - Control playback
- **Scrubber** - Seek to any frame
- **Export button** - Render and save the video

---

## Example Prompts

### Intro/Title Videos

```
Create a Fluvie intro video with:
- Animated title that zooms in with a fade
- Subtitle that slides up after the title
- Sparkle particle effects
- Gradient background transitioning from dark to light
```

### Stats/Data Videos

```
Create a Fluvie stats video showing:
- Title "By The Numbers"
- 3 stat cards with counting animations
- Values: 365 days, 1,234 items, 98% success
- Stagger animation for each card
```

### Photo/Memory Videos

```
Create a Fluvie photo slideshow with:
- 4 polaroid-style photo frames
- Floating animation effect
- Ken Burns zoom on images
- Crossfade transitions between scenes
```

### Outro/Closing Videos

```
Create a Fluvie outro with:
- "Thanks for watching" text
- Confetti particle effect
- Subscribe call-to-action
- Gradient fade to black at end
```

---

## Troubleshooting

### "MCP server not connected"

- Verify the URL is correct: `https://mcp.fluvie.dev/mcp`
- Check your network connection
- Restart your AI assistant

### "Generated code doesn't compile"

- Ask the AI to "fix the compilation errors"
- Ensure you have the latest Fluvie version: `flutter pub upgrade fluvie`

### "Video shows black screen"

- Make sure `VideoPreview` wraps your `Video` widget
- The `Video` widget alone won't animate without `FrameProvider` (which `VideoPreview` provides)

### "Export fails"

- Ensure FFmpeg is installed and in PATH
- Check the console for FFmpeg error messages
- Try running `ffmpeg -version` in terminal

---

## Next Steps

- [Widget Reference](../widgets/README.md) - Explore all available widgets
- [Templates](../templates/README.md) - Use pre-built templates
- [Manual Setup](with-flutter.md) - Learn the framework in detail
- [Headless Rendering](headless.md) - Server-side video generation
