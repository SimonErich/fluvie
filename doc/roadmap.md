# Fluvie Roadmap

This document outlines the planned features and improvements for Fluvie.

## Released (0.1.x) ✅

### Core Features
- ✅ **Declarative Video Composition API** - Use Flutter widgets to define video content
- ✅ **Frame-Perfect Rendering** - Precise control over timing and animations
- ✅ **Layer System** - Z-indexed layers with time-based visibility and fade transitions
- ✅ **Audio Support** - Background music, audio tracks with trim and fade
- ✅ **Cross-Platform** - Desktop (Linux, macOS, Windows) and Web support
- ✅ **Pluggable FFmpeg** - Use native FFmpeg or WASM for web

### Advanced Features
- ✅ **TimeConsumer Widget** - Frame-based animation builder
- ✅ **Sequence System** - Time-bounded content blocks with transitions
- ✅ **Video Sequences** - Embed and trim external video files
- ✅ **Text Animations** - FadeText with interpolation support
- ✅ **Sync Anchors** - Synchronize animations to audio beats
- ✅ **BPM Detection** - Audio analysis for beat-synchronized animations
- ✅ **Template System** - Spotify Wrapped-style templates
- ✅ **Interactive Gallery** - Modern example showcase with glassmorphism UI
- ✅ **Impeller Renderer Detection** - Warnings for Skia usage

### Developer Experience
- ✅ **Comprehensive Documentation** - 100+ markdown files
- ✅ **BDD Tests** - Gherkin feature files with step definitions
- ✅ **CI/CD Pipeline** - Automated testing and coverage
- ✅ **Migration Guide** - Upgrading between versions

---

## In Progress (0.2.x) 🚧

### Error Handling Improvements
- 🚧 **Custom Exception Types** - FluvieException hierarchy for better debugging
- 🚧 **Detailed Error Messages** - Context-aware error reporting
- 🚧 **Error Recovery Examples** - Documentation for handling failures

### Performance Optimizations
- 🚧 **Memory Usage Optimization** - Reduce peak memory consumption
- 🚧 **Render Speed Improvements** - Faster frame capture and encoding
- 🚧 **Benchmark Documentation** - Performance characteristics across platforms

### Mobile Support
- 🚧 **iOS Support** - Native FFmpeg via ffmpeg_kit_flutter
- 🚧 **Android Support** - FFmpeg integration for Android
- 🚧 **Mobile Examples** - Sample apps for iOS/Android

---

## Planned (0.3.x) 📋

### Video Effects System
- 📋 **Visual Effects** - Blur, brightness, contrast, saturation
- 📋 **Color Filters** - Vintage, cinematic, sepia, etc.
- 📋 **Transition Effects** - Wipe, dissolve, slide, zoom
- 📋 **Custom Effect API** - Build your own effects

### Real-time Preview
- 📋 **Preview with Audio** - Hear audio while scrubbing timeline
- 📋 **Playback Controls** - Play/pause preview at target FPS
- 📋 **Preview Optimization** - Faster preview rendering mode

### Templates & Presets
- 📋 **Instagram Stories Templates** - Vertical video templates
- 📋 **TikTok-style Templates** - Short-form video templates
- 📋 **YouTube Intro Templates** - Channel intro animations
- 📋 **Lower Thirds** - Name/title overlay templates

---

## Future Considerations (0.4.x+) 💭

### Advanced Rendering
- 💭 **GPU-Accelerated Rendering** - Use GPU for faster rendering
- 💭 **Multi-threaded Encoding** - Parallel frame rendering
- 💭 **Distributed Rendering** - Cloud rendering integration
- 💭 **Progressive Rendering** - Stream output while rendering

### 3D & Advanced Graphics
- 💭 **3D Scene Support** - Basic 3D animations
- 💭 **Particle Systems** - Advanced particle effects
- 💭 **Vector Graphics** - SVG animation support
- 💭 **Advanced Masking** - Complex masking and compositing

### Plugin System
- 💭 **Custom Effect Plugins** - Third-party effect marketplace
- 💭 **Template Plugins** - Shareable template packages
- 💭 **Codec Plugins** - Additional video codecs
- 💭 **Cloud Provider Plugins** - Render to cloud services

### Live Streaming
- 💭 **RTMP Streaming** - Stream to Twitch, YouTube, etc.
- 💭 **WebRTC Support** - Real-time video communication
- 💭 **Live Composition** - Dynamic composition updates during streaming

### AI Integration
- 💭 **Auto Subtitles** - Speech-to-text subtitle generation
- 💭 **Smart Cropping** - AI-powered video framing
- 💭 **Scene Detection** - Automatic scene transition detection
- 💭 **Audio Enhancement** - Noise reduction, normalization

---

## Version Compatibility

| Version | Flutter | Dart | Status |
|---------|---------|------|--------|
| 0.1.x   | >=3.3.0 | >=3.10.0 | Current |
| 0.2.x   | >=3.3.0 | >=3.10.0 | In Progress |
| 0.3.x   | >=3.10.0 | >=3.10.0 | Planned |

---

## Release Schedule

Fluvie follows **semantic versioning** and aims for:

- **Patch releases** (0.1.x): Bug fixes, documentation updates - As needed
- **Minor releases** (0.x.0): New features, non-breaking changes - Every 2-3 months
- **Major releases** (x.0.0): Breaking changes, major rewrites - As needed

---

## Contributing to the Roadmap

We welcome community input on the roadmap! Here's how you can help:

### Request a Feature
- [Open a feature request](https://github.com/simonerich/fluvie/issues/new?labels=enhancement)
- Vote on existing feature requests with 👍
- Join discussions on [GitHub Discussions](https://github.com/simonerich/fluvie/discussions)

### Contribute Code
- Check issues labeled `help wanted` or `good first issue`
- Comment on roadmap items you'd like to work on
- See [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines

### Sponsor Development
- Sponsorship accelerates development of high-priority features
- Contact the maintainers for sponsorship opportunities

---

## Decision Process

Features are prioritized based on:

1. **User Impact** - How many users will benefit?
2. **Implementation Complexity** - Effort required vs value delivered
3. **Platform Parity** - Does it work across all platforms?
4. **Community Interest** - Upvotes, discussions, and contributions
5. **Maintenance Burden** - Long-term support requirements

---

## Stay Updated

- **Watch this repository** to get notified of releases
- **Follow release notes** in [CHANGELOG.md](../CHANGELOG.md)
- **Join discussions** for early access to beta features
- **Subscribe to GitHub releases** for version announcements

---

**Last Updated**: 2025-12-29

Have a feature idea not on this roadmap? [Let us know!](https://github.com/simonerich/fluvie/discussions/new)
