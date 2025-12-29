# Contributing to Fluvie

Thank you for your interest in contributing to Fluvie! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## Getting Started

### Prerequisites

- Flutter SDK >=3.3.0
- Dart SDK >=3.10.0
- FFmpeg (for testing rendering)
- Git

### Setup

1. Fork the repository on GitHub

2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/fluvie.git
   cd fluvie
   ```

3. Add the upstream remote:
   ```bash
   git remote add upstream https://github.com/simonerich/fluvie.git
   ```

4. Install dependencies:
   ```bash
   flutter pub get
   ```

5. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

6. Run tests to ensure everything works:
   ```bash
   flutter test
   ```

## Development Workflow

### Creating a Branch

Create a branch for your work:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### Making Changes

1. Write your code following the project style guidelines
2. Add tests for new functionality
3. Update documentation as needed
4. Run the analyzer and fix any issues:
   ```bash
   dart analyze
   ```

5. Format your code:
   ```bash
   dart format .
   ```

6. Run all tests:
   ```bash
   flutter test
   ```

### Running Tests with Coverage

Generate and view code coverage reports:

```bash
# Generate coverage data
flutter test --coverage

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Open the report in your browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
start coverage/html/index.html  # Windows
```

**Coverage Requirements**:

- Maintain >80% overall coverage
- New features must include tests
- Critical rendering code should have >90% coverage
- PRs that decrease coverage without justification may be rejected

**Tips for good coverage**:

- Test both success and failure paths
- Include edge cases (empty inputs, boundary conditions)
- Test error handling and exception throwing
- Mock external dependencies (FFmpeg, file I/O)

### Committing

Write clear, concise commit messages:

```
feat: add Layer widget with time-based visibility

- Add startFrame/endFrame for visibility control
- Add fadeInFrames/fadeOutFrames for transitions
- Add blendMode support for compositing
```

Use conventional commit prefixes:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test changes
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

### Submitting a Pull Request

1. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Open a Pull Request on GitHub

3. Fill out the PR template completely

4. Wait for CI to pass and address any review feedback

## Code Style

### General Guidelines

- Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide
- Use meaningful variable and function names
- Keep functions focused and small
- Write dartdoc comments for public APIs

### Naming Conventions

- Classes: `PascalCase`
- Functions/variables: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE`
- Files: `snake_case.dart`

### Documentation

All public APIs should have dartdoc comments:

```dart
/// A layer with time-based visibility for video compositions.
///
/// The layer automatically shows and hides based on the current frame,
/// with optional fade transitions.
///
/// Example:
/// ```dart
/// Layer(
///   startFrame: 30,
///   endFrame: 120,
///   fadeInFrames: 15,
///   child: MyWidget(),
/// )
/// ```
class Layer extends StatelessWidget {
  // ...
}
```

## Testing

### Writing Tests

- Place tests in the `test/` directory
- Mirror the `lib/` structure where appropriate
- Use descriptive test names

```dart
test('Layer is visible when frame is within range', () {
  // Test implementation
});
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/my_test.dart

# Run with coverage
flutter test --coverage
```

## Project Structure

```
fluvie/
├── lib/
│   ├── fluvie.dart              # Main exports
│   └── src/
│       ├── capture/             # Frame capture
│       ├── domain/              # Data models
│       ├── encoding/            # FFmpeg integration
│       ├── integration/         # Render service
│       ├── presentation/        # Widgets
│       ├── preview/             # Audio preview
│       └── utils/               # Utilities
├── test/                        # Tests
├── example/                     # Example app
└── docs/                        # Documentation
```

## Reporting Issues

When reporting issues, please include:

1. A clear description of the problem
2. Steps to reproduce
3. Expected vs actual behavior
4. Flutter/Dart version (`flutter --version`)
5. Fluvie version
6. Platform (Linux, macOS, Windows, Web)
7. Relevant code snippets or error messages

## Feature Requests

Feature requests are welcome! Please:

1. Check existing issues to avoid duplicates
2. Describe the use case clearly
3. Explain why existing functionality doesn't meet your needs
4. If possible, suggest an API design

## Questions?

If you have questions about contributing, feel free to:

- Open a GitHub Discussion
- Create an issue with the "question" label

Thank you for contributing to Fluvie!
