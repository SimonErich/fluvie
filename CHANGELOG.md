# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Custom Exception Types**: Comprehensive exception hierarchy for better error handling
  - `FluvieException` base class for all Fluvie errors
  - `FFmpegNotFoundException` for missing FFmpeg executable
  - `FFmpegExecutionException` for FFmpeg command failures
  - `RenderException` for rendering pipeline errors
  - `FrameCaptureException` for frame capture failures
  - `InvalidConfigurationException` for configuration errors
  - `AudioProcessingException` for audio processing failures
  - `FileNotFoundException` and `FileIOException` for file operations
  - `VideoProbeException` for video probing errors
  - `TimelineException` for timeline configuration errors
  - `UnsupportedPlatformException` for platform-specific limitations
- **Documentation**: Comprehensive guides and references
  - `doc/FAQ.md` - Frequently asked questions (20+ Q&As)
  - `doc/roadmap.md` - Project roadmap with release planning
  - `doc/cookbook/` - Recipe-style documentation with 4+ practical examples
    - Animated titles with motion effects
    - Crossfade transitions between scenes
    - Audio-synchronized animations
    - Performance optimization techniques
  - `doc/security/best-practices.md` - Security guidelines for production use
  - `doc/advanced/error-handling.md` - Complete error handling guide
- **Coverage Instructions**: Added test coverage reporting to CONTRIBUTING.md
  - Instructions for generating HTML coverage reports
  - Coverage requirements (>80% overall, >90% critical code)
  - Tips for writing effective tests
- **CI/CD Improvements**: Enhanced GitHub Actions workflows for production readiness
  - Multi-platform testing (Ubuntu, macOS, Windows)
  - Multi-version Flutter testing (3.3.10, 3.10.0, stable)
  - Coverage threshold enforcement (80% minimum)
  - Security vulnerability scanning with `dart pub audit`
  - Documentation validation with `dart doc --validate-links`
  - FFmpeg version checking and caching
  - Integration test execution in CI
- **API Documentation**: Comprehensive dartdoc added to public APIs
  - `VideoEncoderService` class and methods fully documented
  - `VideoEncodingSession` class with usage examples
  - `FluviePlatform` interface documentation
  - All public methods include parameter descriptions and `@throws` annotations
- **Marketing Website**: Professional marketing site in `website/` directory for GitHub Pages
  - Single-page responsive design deployed at `fluvie.dev`
  - Interactive Monaco Editor code playground with 4 live examples
  - Feature showcase, use cases, templates gallery
  - Complete documentation hub with links to all resources
  - MCP Server integration section
  - SEO-optimized with Schema.org, Open Graph, Twitter Cards
  - Mobile-first responsive design
  - Smooth scroll animations and glassmorphic UI
  - Architecture diagram visualizing dual-engine model
  - Deployment guide and local development setup
- **Demo Data Management**: Added `example/assets/demo_data/README.md` with instructions
  - Documents why binary files are not in repository
  - Provides sources for obtaining demo files (Pexels, Free Music Archive)
  - Explains Git LFS alternative for teams needing shared binary files

### Changed

- **Repository Cleanup**: Complete git history rewrite to remove binary files
  - Removed 58MB of video/audio/image files from all commits
  - Repository size reduced from 84MB to 25MB (70% reduction)
  - Binary files now properly excluded via `.gitignore`
  - Demo files remain available locally for development but are not tracked

- **Error Handling**: Migrated from generic exceptions to custom types
  - `video_encoder_service.dart` now uses `InvalidConfigurationException` and `AudioProcessingException`
  - `render_service.dart` now uses `InvalidConfigurationException`
  - `frame_sequencer.dart` now uses `FrameCaptureException` with detailed context
  - `video_probe_service.dart` migrated to use new `VideoProbeException` from exceptions module
- **CONTRIBUTING.md**: Fixed Flutter SDK version requirement (was "3.38.3", now ">=3.3.0")
- **GitHub Actions**: Complete overhaul of CI/CD pipeline
  - Test job now uses matrix strategy for cross-platform/version testing
  - Coverage upload restricted to Ubuntu + stable Flutter only (prevents duplicates)
  - FFmpeg installation now platform-specific (apt/brew/choco)
  - Added `needs: analyze` dependency to test job

### Deprecated

- `SummaryData.totalStats`: Use `stats` instead (will be removed in v1.0.0)
- `SummaryData.userName`: Use `name` instead (will be removed in v1.0.0)

### Fixed

- Corrected Flutter SDK version in contributing guidelines
- Improved error messages with actionable context
- CI coverage enforcement now properly fails builds below 80% threshold
- codecov upload now uses `fail_ci_if_error: true` for strict enforcement

## [0.1.0] - 2024-12-06

### Added
- **Layer System**: New `Layer` widget with time-based visibility, fade transitions, blend modes, and z-index support
- **LayerStack Enhancements**: Z-index sorting for explicit layer ordering
- **AnimatedLayer**: Layer with built-in `TimeConsumer` for simplified animations
- **LayerGroup**: Group multiple layers with shared visibility timing
- **SpatialProperties**: Type-safe spatial transformation properties replacing generic Map
- **FFmpegProvider Architecture**: Pluggable FFmpeg backend system
  - `FFmpegProvider` interface for custom implementations
  - `ProcessFFmpegProvider` for desktop platforms (Linux, macOS, Windows)
  - `WasmFFmpegProvider` for web browser support via ffmpeg.wasm
  - `FFmpegProviderRegistry` for platform-based provider selection
- **SlideTransition**: New transition widget for sliding between content
- **GitHub CI/CD**: Automated workflows for testing, documentation, and publishing
- **Contributing Guide**: CONTRIBUTING.md with development setup instructions

### Changed
- **BREAKING**: Renamed `Clip` to `Sequence` throughout the API
- **BREAKING**: Renamed `ClipConfig` to `SequenceConfig`
- **BREAKING**: Audio time parameters changed from milliseconds to frames for consistency
  - `trimStartMs` → `trimStartFrame`
  - `trimEndMs` → `trimEndFrame`
  - Helper methods `trimStartFrameToMs()` and `trimEndFrameToMs()` added for conversion
- **CrossFadeTransition**: Now actually implements cross-fade animation (was previously a stub)
- **VideoSequence**: Trim parameters now properly wired to FFmpeg filter graph

### Deprecated
- `Clip` typedef (use `Sequence` instead)
- `VideoClip` typedef (use `VideoSequence` instead)
- `TextClip` typedef (use `TextSequence` instead)
- `ClipConfig` typedef (use `SequenceConfig` instead)

### Fixed
- CrossFadeTransition now properly fades between children
- Layer opacity calculations using modern Flutter API (`withValues` instead of deprecated `withOpacity`)

## [0.0.1] - 2024-11-24

### Added
- Initial release
- `VideoComposition` widget for defining video parameters
- `Clip` widget for time-bounded content
- `TimeConsumer` widget for frame-based animations
- `RenderService` for orchestrating the render pipeline
- `VideoEncoderService` with FFmpeg Process.run integration
- `FrameSequencer` for capturing widget frames
- Basic audio support with `AudioTrack` and `BackgroundAudio`
- Gherkin-style tests for core features
- Linux desktop plugin
