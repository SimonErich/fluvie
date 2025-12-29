# Contributing to Fluvie

> **Help make programmatic video generation better**

Thank you for your interest in contributing to Fluvie! This guide will help you get started.

## Table of Contents

- [Overview](#overview)
- [Ways to Contribute](#ways-to-contribute)
- [Getting Started](#getting-started)
- [Contribution Process](#contribution-process)
- [Guides](#guides)

---

## Overview

Fluvie is an open-source project that welcomes contributions of all kinds. Whether you're fixing a bug, adding a feature, improving documentation, or helping other users, your contributions are valued.

---

## Ways to Contribute

### Code Contributions

- **Bug Fixes**: Fix issues reported in GitHub Issues
- **Features**: Implement new widgets, animations, effects, or templates
- **Performance**: Optimize rendering speed or memory usage
- **Platform Support**: Improve support for different platforms

### Documentation

- **Tutorials**: Write step-by-step guides
- **Examples**: Create example videos and compositions
- **Translations**: Help translate documentation
- **Typo Fixes**: Fix errors in existing documentation

### Community

- **Answer Questions**: Help users on GitHub Discussions
- **Report Bugs**: Submit detailed bug reports
- **Feature Requests**: Suggest improvements
- **Share**: Tell others about Fluvie

---

## Getting Started

### 1. Fork the Repository

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/fluvie.git
cd fluvie
```

### 2. Set Up Development Environment

```bash
# Install dependencies
flutter pub get

# Install FFmpeg (required for rendering)
# macOS: brew install ffmpeg
# Ubuntu: sudo apt install ffmpeg
# Windows: choco install ffmpeg
```

### 3. Run Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/fluvie_test.dart

# Run with coverage
flutter test --coverage
```

### 4. Run the Example App

```bash
cd example
flutter run
```

**Guide**: [Development Setup](development-setup.md)

---

## Contribution Process

### 1. Find or Create an Issue

Before starting work:

- Check [existing issues](https://github.com/anthropics/fluvie/issues)
- For new features, open a discussion first
- Get feedback on your approach

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### 3. Make Your Changes

- Follow the [code style guide](code-style.md)
- Write tests for new functionality
- Update documentation as needed

### 4. Test Your Changes

```bash
# Run tests
flutter test

# Run the example to verify
cd example && flutter run
```

### 5. Submit a Pull Request

- Push your branch to your fork
- Open a PR against the `main` branch
- Fill out the PR template
- Link related issues

### 6. Review Process

- Maintainers will review your PR
- Address any feedback
- Once approved, your PR will be merged

---

## Guides

| Guide | Description |
|-------|-------------|
| [Development Setup](development-setup.md) | Set up your development environment |
| [Testing](testing.md) | How to write and run tests |
| [Code Style](code-style.md) | Coding standards and conventions |
| [Support](support.md) | Getting help and reporting issues |

---

## Quick Links

- [GitHub Repository](https://github.com/anthropics/fluvie)
- [Issue Tracker](https://github.com/anthropics/fluvie/issues)
- [Discussions](https://github.com/anthropics/fluvie/discussions)
- [Example Gallery](../tutorials/README.md)

---

## Code of Conduct

Be respectful and inclusive. We're all here to build something great together.

- Be welcoming to newcomers
- Provide constructive feedback
- Focus on what's best for the project
- Show empathy towards others

---

## Recognition

Contributors are recognized in:

- The CONTRIBUTORS.md file
- Release notes when their features ship
- The project README

Thank you for contributing to Fluvie!

