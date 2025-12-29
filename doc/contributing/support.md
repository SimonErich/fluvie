# Support

> **Getting help and reporting issues**

This guide explains how to get help with Fluvie and how to report issues effectively.

## Table of Contents

- [Getting Help](#getting-help)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)
- [Security Issues](#security-issues)
- [Community Guidelines](#community-guidelines)

---

## Getting Help

### Documentation

Start with the documentation:

1. **[Getting Started](../getting-started/README.md)** - Installation and first steps
2. **[Tutorials](../tutorials/README.md)** - Step-by-step guides
3. **[Widget Reference](../widgets/README.md)** - Complete widget documentation
4. **[FAQ](#frequently-asked-questions)** - Common questions

### GitHub Discussions

For questions and discussions:

- Visit [GitHub Discussions](https://github.com/anthropics/fluvie/discussions)
- Search for existing answers first
- Post in the appropriate category:
  - **Q&A**: Technical questions
  - **Ideas**: Feature suggestions
  - **Show and Tell**: Share your creations
  - **General**: Other discussions

### Stack Overflow

For programming questions:

- Tag your question with `fluvie` and `flutter`
- Include a minimal reproducible example
- Show what you've tried

---

## Reporting Bugs

### Before Reporting

1. **Search existing issues** - Your bug may already be reported
2. **Update to latest version** - The bug may be fixed
3. **Check documentation** - Ensure correct usage
4. **Isolate the issue** - Create a minimal example

### Bug Report Template

When creating an issue, include:

```markdown
## Description
A clear description of the bug.

## Steps to Reproduce
1. Create a Video with...
2. Add a Scene containing...
3. Call RenderService.execute()
4. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Minimal Reproduction Code

```dart
// Minimal code that reproduces the issue
final video = Video(
  fps: 30,
  width: 1080,
  height: 1920,
  scenes: [
    Scene(
      durationInFrames: 30,
      children: [
        // Your widget setup
      ],
    ),
  ],
);

await RenderService.execute(
  composition: video,
  outputPath: 'output.mp4',
  tester: tester,
);
```

## Environment

- Fluvie version: [e.g., 1.0.0]
- Flutter version: [e.g., 3.16.0]
- Dart version: [e.g., 3.2.0]
- Platform: [e.g., macOS 14.0, Ubuntu 22.04, Windows 11]
- FFmpeg version: [e.g., 5.1.2]

## Additional Context

- Error messages or stack traces
- Screenshots or video recordings
- Relevant logs
```

### Good Bug Report Example

```markdown
## Description
Audio playback in preview mode is delayed by approximately 500ms compared to visual elements.

## Steps to Reproduce
1. Create a Video with a SyncAnchor at frame 30
2. Add an AudioTrack synced to that anchor
3. Run the preview
4. Observe audio plays noticeably after the visual cue

## Expected Behavior
Audio should play exactly when the visual element appears at frame 30.

## Actual Behavior
Audio plays approximately 500ms after the visual element appears.

## Minimal Reproduction Code
[See attached code]

## Environment
- Fluvie version: 1.2.0
- Flutter version: 3.16.5
- Platform: macOS 14.2.1
- FFmpeg version: 6.1

## Additional Context
This only happens in preview mode. Rendered videos have correct sync.
Tested on two different Macs with same result.
```

---

## Feature Requests

### Before Requesting

1. **Check the roadmap** - It may already be planned
2. **Search discussions** - Others may have suggested it
3. **Consider alternatives** - Can existing features achieve your goal?

### Feature Request Template

```markdown
## Feature Description
A clear description of the feature you'd like.

## Use Case
Why do you need this feature? What problem does it solve?

## Proposed Solution
How do you envision this working?

## Alternatives Considered
What other approaches have you considered?

## Additional Context
- Mockups or examples from other tools
- Priority/importance to your workflow
```

### Good Feature Request Example

```markdown
## Feature Description
Add support for animated SVG paths as a widget.

## Use Case
I'm creating infographics that animate line graphs and icons.
Currently I have to convert SVGs to images or use CustomPaint manually.

## Proposed Solution
A widget like:
```dart
AnimatedSvgPath(
  svgPath: 'M10 10 L100 100...',
  startFrame: 0,
  durationInFrames: 60,
  strokeColor: Colors.blue,
  strokeWidth: 2,
)
```

## Alternatives Considered
- CustomPaint: Works but requires manual animation math
- Rive/Lottie: External tools, different workflow

## Additional Context
Similar to how motion graphics tools like After Effects animate paths.
Would make Fluvie more competitive for infographic videos.
```

---

## Security Issues

### Reporting Security Vulnerabilities

**Do not report security issues publicly.**

Instead:

1. Email security concerns to the maintainers
2. Include detailed description of the vulnerability
3. Provide steps to reproduce if possible
4. Allow time for the issue to be addressed before disclosure

### What Qualifies as Security Issue

- Remote code execution
- Data exposure
- Authentication bypass
- Other security vulnerabilities

---

## Frequently Asked Questions

### Installation

**Q: FFmpeg not found error**

A: Ensure FFmpeg is installed and in your PATH:
```bash
# Check if accessible
which ffmpeg
ffmpeg -version

# If not found, install:
# macOS: brew install ffmpeg
# Ubuntu: sudo apt install ffmpeg
# Windows: choco install ffmpeg
```

**Q: Flutter version incompatibility**

A: Fluvie requires Flutter 3.16+. Update with:
```bash
flutter upgrade
```

### Rendering

**Q: Render is very slow**

A: Try these optimizations:
- Use `RenderQuality.preview` for testing
- Reduce resolution during development
- Avoid excessive `saveLayer` operations (Opacity widgets)
- See [Performance Tips](../advanced/performance-tips.md)

**Q: Output video has no audio**

A: Check:
- AudioTrack is properly configured
- Audio file path is correct
- File format is supported (MP3, AAC, WAV)
- Volume is not set to 0

**Q: Video doesn't play on my device**

A: Some codecs have limited support:
```dart
// Use H.264 for maximum compatibility
EncodingConfig(
  videoCodec: VideoCodec.h264,
  audioCodec: AudioCodec.aac,
  outputFormat: OutputFormat.mp4,
)
```

### Widgets

**Q: TimeConsumer not updating**

A: Ensure you're wrapping your composition in `RenderModeProvider`:
```dart
RenderModeProvider(
  frameNotifier: FrameReadyNotifier(0),
  child: MyComposition(),
)
```

**Q: Animation timing is off**

A: Remember Fluvie uses frame numbers, not duration:
```dart
// 30fps: 1 second = 30 frames
final durationInFrames = (seconds * fps).round();
```

**Q: Custom fonts not working**

A: Fonts must be declared in pubspec.yaml:
```yaml
flutter:
  fonts:
    - family: MyFont
      fonts:
        - asset: assets/fonts/MyFont.ttf
```

---

## Community Guidelines

### Be Respectful

- Treat others with respect
- Assume good intentions
- Be patient with newcomers

### Be Helpful

- Share knowledge generously
- Point to documentation when relevant
- Provide complete answers when possible

### Be Constructive

- Focus on solutions, not blame
- Offer alternatives when disagreeing
- Celebrate others' successes

### When Responding to Issues

- Acknowledge the reporter's effort
- Ask clarifying questions politely
- Thank contributors for their time

---

## Contact

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community
- **Email**: For security issues only

---

## Related

- [Contributing](README.md) - How to contribute
- [Development Setup](development-setup.md) - Environment setup
- [Testing](testing.md) - Testing guidelines

