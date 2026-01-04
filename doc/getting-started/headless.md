# Getting Started with Fluvie (Headless/Server-Side)

> **Generate videos on servers, CI/CD pipelines, and without a display**

This guide covers running Fluvie in headless mode for automated video generation on servers, in Docker containers, and CI/CD pipelines.

## Table of Contents

- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Option 1: Flutter Test Mode](#option-1-flutter-test-mode)
- [Option 2: Flutter Headless Linux](#option-2-flutter-headless-linux)
- [Docker Setup](#docker-setup)
- [GitHub Actions](#github-actions)
- [API Server Example](#api-server-example)

---

## Use Cases

Headless Fluvie is ideal for:
- **Automated video generation** - Generate videos from data/APIs
- **CI/CD pipelines** - Create videos as part of your build process
- **Video APIs** - Build services that generate videos on demand
- **Batch processing** - Generate many videos from templates
- **Server-side rendering** - No user display required

---

## Prerequisites

- **Flutter SDK** 3.16+
- **FFmpeg** installed on the server
- **Linux server** (recommended) or Docker container

---

## Option 1: Flutter Test Mode

The simplest approach is using Flutter's test framework, which provides a headless widget binding.

### Create a Video Generator Script

`lib/video_generator.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/declarative.dart';

/// Generates a video from data.
class VideoGenerator {
  /// Generate a personalized video.
  static Video createVideo({
    required String title,
    required String subtitle,
    required List<String> stats,
  }) {
    return Video(
      fps: 30,
      width: 1080,
      height: 1920,
      scenes: [
        // Intro scene
        Scene(
          durationInFrames: 90,
          background: Background.gradient(
            colors: {
              0: const Color(0xFF1a1a2e),
              90: const Color(0xFF0f3460),
            },
          ),
          children: [
            VCenter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedText.slideUpFade(
                    title,
                    duration: 30,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedText.fadeIn(
                    subtitle,
                    startFrame: 30,
                    duration: 20,
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Stats scene
        Scene(
          durationInFrames: 120,
          background: Background.solid(const Color(0xFF0f3460)),
          children: [
            VCenter(
              child: VColumn(
                spacing: 24,
                stagger: StaggerConfig.slideUp(delay: 15, duration: 20),
                children: stats
                    .map((stat) => Text(
                          stat,
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

### Create a Test-Based Render Script

`test/render_video_test.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:my_app/video_generator.dart';

void main() {
  testWidgets('Generate personalized video', (tester) async {
    // Create video from data
    final video = VideoGenerator.createVideo(
      title: 'Your 2024 Wrapped',
      subtitle: 'A year in review',
      stats: [
        '365 days tracked',
        '1,234 activities',
        '98% completion rate',
      ],
    );

    // Build the widget tree
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: video.width.toDouble(),
            height: video.height.toDouble(),
            child: video,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Export the video
    final path = await VideoExporter(video)
      .withQuality(RenderQuality.high)
      .withFileName('wrapped_2024.mp4')
      .withProgress((p) => print('Progress: ${(p * 100).toInt()}%'))
      .render();

    print('Video saved to: $path');

    // Copy to output directory
    final outputDir = Directory('output');
    if (!outputDir.existsSync()) {
      outputDir.createSync();
    }
    await File(path).copy('output/wrapped_2024.mp4');

    expect(File('output/wrapped_2024.mp4').existsSync(), true);
  });
}
```

### Run the Script

```bash
flutter test test/render_video_test.dart --no-sound-null-safety
```

---

## Option 2: Flutter Headless Linux

For production servers, use Flutter's Linux embedder in headless mode.

### Setup Script

`bin/generate_video.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluvie/fluvie.dart';
import 'package:my_app/video_generator.dart';

Future<void> main(List<String> args) async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Parse arguments
  final title = args.isNotEmpty ? args[0] : 'Hello World';
  final outputPath = args.length > 1 ? args[1] : 'output.mp4';

  print('Generating video: $title');
  print('Output: $outputPath');

  // Create and render video
  final video = VideoGenerator.createVideo(
    title: title,
    subtitle: 'Generated with Fluvie',
    stats: ['Headless rendering', 'Server-side', 'Automated'],
  );

  final path = await VideoExporter(video)
    .withQuality(RenderQuality.high)
    .withFileName(outputPath)
    .withProgress((p) {
      stdout.write('\rProgress: ${(p * 100).toInt()}%');
    })
    .render();

  print('\nVideo saved to: $path');
  exit(0);
}
```

### Run with Virtual Framebuffer (Linux)

```bash
# Install xvfb (virtual framebuffer)
sudo apt-get install xvfb

# Run with virtual display
xvfb-run flutter run -d linux bin/generate_video.dart "My Title" "output.mp4"
```

---

## Docker Setup

### Dockerfile

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    ffmpeg \
    xvfb \
    libgtk-3-0 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxrandr2 \
    libxi6 \
    libxcursor1 \
    libxdamage1 \
    libxfixes3 \
    libxcomposite1 \
    libasound2 \
    libatk1.0-0 \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

# Pre-download Flutter dependencies
RUN flutter doctor
RUN flutter precache --linux

# Set up working directory
WORKDIR /app

# Copy project files
COPY pubspec.* ./
RUN flutter pub get

COPY . .

# Build for Linux
RUN flutter build linux --release

# Entry point script
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
```

### docker-entrypoint.sh

```bash
#!/bin/bash
set -e

# Start virtual framebuffer
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# Wait for Xvfb to start
sleep 2

# Run the video generator
exec flutter test test/render_video_test.dart "$@"
```

### Build and Run

```bash
# Build Docker image
docker build -t fluvie-generator .

# Run with output volume
docker run -v $(pwd)/output:/app/output fluvie-generator
```

---

## GitHub Actions

### `.github/workflows/generate-video.yml`

```yaml
name: Generate Video

on:
  workflow_dispatch:
    inputs:
      title:
        description: 'Video title'
        required: true
        default: 'Hello World'
      output_name:
        description: 'Output file name'
        required: true
        default: 'output.mp4'

jobs:
  generate:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install system dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y \
            ffmpeg \
            xvfb \
            libgtk-3-0 \
            libx11-6 \
            libnss3 \
            libxss1 \
            libasound2

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Generate video
        run: |
          export DISPLAY=:99
          Xvfb :99 -screen 0 1920x1080x24 &
          sleep 3
          flutter test test/render_video_test.dart \
            --dart-define=TITLE="${{ github.event.inputs.title }}" \
            --dart-define=OUTPUT="${{ github.event.inputs.output_name }}"

      - name: Upload video artifact
        uses: actions/upload-artifact@v4
        with:
          name: video
          path: output/*.mp4
```

---

## API Server Example

### Video Generation API

`bin/server.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:my_app/video_generator.dart';
import 'package:fluvie/fluvie.dart';

void main() async {
  final router = Router();

  router.post('/generate', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final title = data['title'] as String? ?? 'Untitled';
    final subtitle = data['subtitle'] as String? ?? '';
    final stats = (data['stats'] as List?)?.cast<String>() ?? [];

    // Generate video
    final video = VideoGenerator.createVideo(
      title: title,
      subtitle: subtitle,
      stats: stats,
    );

    final outputPath = await VideoExporter(video)
      .withQuality(RenderQuality.high)
      .withFileName('${DateTime.now().millisecondsSinceEpoch}.mp4')
      .render();

    // Return video file
    final videoFile = File(outputPath);
    final bytes = await videoFile.readAsBytes();

    return Response.ok(
      bytes,
      headers: {
        'Content-Type': 'video/mp4',
        'Content-Disposition': 'attachment; filename="video.mp4"',
      },
    );
  });

  final handler = Pipeline()
    .addMiddleware(logRequests())
    .addHandler(router);

  final server = await io.serve(handler, '0.0.0.0', 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}
```

### API Usage

```bash
curl -X POST http://localhost:8080/generate \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My 2024 Recap",
    "subtitle": "A year in review",
    "stats": ["365 days", "1000 activities", "98% complete"]
  }' \
  --output video.mp4
```

---

## Performance Tips

### 1. Use Lower Resolution for Testing

```dart
Video(
  width: 540,   // Half resolution
  height: 960,  // Half resolution
  ...
)
```

### 2. Reduce Quality During Development

```dart
VideoExporter(video)
  .withQuality(RenderQuality.low)  // Faster encoding
  .render();
```

### 3. Enable Frame Caching

```dart
// Pre-warm asset loading
await precacheImage(AssetImage('assets/logo.png'), context);
```

### 4. Use Multiple Cores

FFmpeg automatically uses multiple cores. For batch processing, run exports in parallel:

```dart
await Future.wait([
  VideoExporter(video1).render(),
  VideoExporter(video2).render(),
  VideoExporter(video3).render(),
]);
```

---

## Troubleshooting

### "No display found"

Ensure Xvfb is running:
```bash
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 &
```

### "FFmpeg not found"

Install FFmpeg and verify:
```bash
ffmpeg -version
```

### "Out of memory"

Reduce video resolution or process fewer frames at a time:
```dart
Video(
  width: 720,
  height: 1280,  // Lower resolution
  ...
)
```

### "Slow rendering"

- Use `RenderQuality.low` for testing
- Ensure Impeller is enabled (default in Flutter 3.16+)
- Use SSD storage for temp files

---

## Next Steps

- [Manual Flutter Setup](with-flutter.md) - Understand the framework
- [Vibecoding with MCP](with-mcp.md) - AI-assisted development
- [API Reference](../widgets/README.md) - All available widgets
- [Templates](../templates/README.md) - Pre-built templates
