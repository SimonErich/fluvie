# Development Setup

> **Set up your Fluvie development environment**

This guide walks you through setting up a complete development environment for contributing to Fluvie.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Setup](#repository-setup)
- [IDE Configuration](#ide-configuration)
- [Running the Project](#running-the-project)
- [Project Structure](#project-structure)
- [Common Tasks](#common-tasks)

---

## Prerequisites

### Required

| Tool | Version | Installation |
|------|---------|--------------|
| Flutter | 3.16+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.2+ | Included with Flutter |
| Git | 2.x | [git-scm.com](https://git-scm.com/) |
| FFmpeg | 5.x+ | See [FFmpeg Setup](../getting-started/ffmpeg-setup.md) |

### Recommended

| Tool | Purpose |
|------|---------|
| VS Code | Recommended IDE with Flutter extension |
| Android Studio | Alternative IDE, required for Android emulators |

### Verify Installation

```bash
# Check Flutter
flutter --version
# Flutter 3.16.0 or higher

# Check Dart
dart --version
# Dart SDK version: 3.2.0 or higher

# Check FFmpeg
ffmpeg -version
# ffmpeg version 5.x or higher

# Check Flutter doctor
flutter doctor
# All checks should pass
```

---

## Repository Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub first, then:
git clone https://github.com/YOUR_USERNAME/fluvie.git
cd fluvie

# Add upstream remote
git remote add upstream https://github.com/anthropics/fluvie.git
```

### 2. Install Dependencies

```bash
# Install main package dependencies
flutter pub get

# Install example app dependencies
cd example
flutter pub get
cd ..
```

### 3. Verify Setup

```bash
# Run tests to verify everything works
flutter test

# Should see all tests passing
```

---

## IDE Configuration

### VS Code (Recommended)

#### Extensions

Install these extensions:

- **Dart** - Dart language support
- **Flutter** - Flutter development tools
- **Flutter Intl** - Internationalization (optional)
- **GitLens** - Git integration (optional)

#### Settings

Create or update `.vscode/settings.json`:

```json
{
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.rulers": [80],
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "Dart-Code.dart-code"
  }
}
```

#### Launch Configuration

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Example App",
      "cwd": "example",
      "request": "launch",
      "type": "dart"
    },
    {
      "name": "Run Tests",
      "request": "launch",
      "type": "dart",
      "program": "test/"
    }
  ]
}
```

### Android Studio

1. Open the project folder
2. Go to **File > Settings > Languages & Frameworks > Dart**
3. Set SDK path to your Flutter installation
4. Enable **Format code on save**

---

## Running the Project

### Run Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/fluvie_test.dart

# With verbose output
flutter test --reporter expanded

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run Example App

```bash
cd example

# Run on connected device/emulator
flutter run

# Run on specific device
flutter run -d chrome  # Web
flutter run -d macos   # macOS
flutter run -d linux   # Linux
```

### Run Specific Examples

The example app has a gallery of examples:

```bash
cd example
flutter run

# Navigate to Gallery > Select Example
```

### Generate Code

If you modify code that uses code generation:

```bash
# Run build_runner
dart run build_runner build

# Or watch for changes
dart run build_runner watch
```

---

## Project Structure

```
fluvie/
├── lib/
│   ├── fluvie.dart              # Main export file
│   ├── declarative.dart         # Declarative API exports
│   └── src/
│       ├── capture/             # Frame capture system
│       │   └── frame_sequencer.dart
│       ├── config/              # Configuration classes
│       ├── declarative/         # Declarative widgets (V-prefixed)
│       ├── domain/              # Domain models
│       │   ├── render_config.dart
│       │   ├── audio_config.dart
│       │   └── ...
│       ├── encoding/            # FFmpeg integration
│       │   ├── video_encoder_service.dart
│       │   ├── ffmpeg_filter_graph_builder.dart
│       │   └── ffmpeg_provider/
│       ├── integration/         # Main render service
│       │   └── render_service.dart
│       ├── presentation/        # Core widgets
│       │   ├── video_composition.dart
│       │   ├── scene.dart
│       │   ├── time_consumer.dart
│       │   └── ...
│       ├── preview/             # Preview mode components
│       ├── templates/           # Pre-built templates
│       │   ├── intro/
│       │   ├── ranking/
│       │   ├── data_viz/
│       │   ├── collage/
│       │   ├── thematic/
│       │   └── conclusion/
│       └── utils/               # Utility functions
│
├── example/
│   ├── lib/
│   │   ├── main.dart           # Example app entry
│   │   └── gallery/            # Example gallery
│   │       └── examples/       # Individual examples
│   └── test/
│       └── widget_test.dart
│
├── test/
│   ├── features/               # Gherkin feature tests
│   │   ├── step/               # Step definitions
│   │   └── *.feature           # Feature files
│   ├── presentation/           # Widget tests
│   └── *.dart                  # Unit tests
│
├── doc/                        # Documentation
│   ├── README.md
│   └── ...
│
├── pubspec.yaml               # Package configuration
├── analysis_options.yaml      # Linter configuration
└── README.md                  # Project README
```

---

## Common Tasks

### Adding a New Widget

1. Create widget in `lib/src/presentation/`
2. Export from `lib/fluvie.dart`
3. Add tests in `test/`
4. Add documentation in `doc/widgets/`
5. Add example usage in `example/`

### Adding a New Template

1. Create data class in `lib/src/templates/`
2. Create template widget extending `WrappedTemplate`
3. Add to appropriate category folder
4. Export from `lib/fluvie.dart`
5. Add tests
6. Document in `doc/templates/`

### Adding a New Animation

1. Create in `lib/src/presentation/` or `lib/src/utils/`
2. If `PropAnimation`, add as static factory
3. Add tests
4. Document in `doc/animations/`

### Updating Documentation

1. Documentation is in `doc/`
2. Follow existing format with Table of Contents
3. Include code examples
4. Link to related documentation

---

## Keeping Your Fork Updated

```bash
# Fetch upstream changes
git fetch upstream

# Merge into your main branch
git checkout main
git merge upstream/main

# Push to your fork
git push origin main
```

---

## Troubleshooting

### Flutter Doctor Issues

```bash
flutter doctor -v
# Follow the suggestions for any issues
```

### FFmpeg Not Found

Ensure FFmpeg is in your PATH:

```bash
# Check if FFmpeg is accessible
which ffmpeg

# If not found, add to PATH or reinstall
```

### Tests Failing

```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Run tests again
flutter test
```

### Example App Not Running

```bash
cd example
flutter clean
flutter pub get
flutter run
```

---

## Related

- [Testing](testing.md) - Testing guidelines
- [Code Style](code-style.md) - Coding standards
- [Contributing](README.md) - Contribution overview

