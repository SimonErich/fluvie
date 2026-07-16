/// The files `fluvie init` writes: a minimal Flutter package that is nothing but
/// the composition and its assets.
///
/// There is no app, no `main.dart`, no capture harness, no registry, and no
/// platform directories. `flutter test` needs only a `pubspec.yaml` in its
/// working directory, and the harness a render runs is generated per render, so
/// the pubspec is the entire project. It also gives the editor its analysis
/// context, which is what makes `package:fluvie` resolve and the lints run while
/// you type.
library;

import 'package:fluvie_cli/src/init_support.dart';

/// The `pubspec.yaml` for a new Fluvie project named [packageName].
///
/// `flutter: assets:` is deliberately absent: the CLI derives it from the asset
/// tree on every render, because Flutter bundles a declared asset directory
/// non-recursively and a hand-written `assets/` would silently miss anything in
/// a subdirectory.
String projectPubspecSource({required String packageName}) =>
    '''
name: $packageName
description: A Fluvie video project.
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter
  fluvie: $fluvieDependencyVersion

dev_dependencies:
  flutter_test:
    sdk: flutter
  # The generated capture harness loads the real bundled fonts through this;
  # without it `flutter test` draws every glyph as an Ahem box.
  alchemist: $alchemistDependencyVersion
  custom_lint: $customLintDependencyVersion
  fluvie_lints: $fluvieLintsDependencyVersion
''';

/// The `.gitignore` for a new Fluvie project.
String projectGitignoreSource() => '''
# The CLI's generated harnesses and preview scaffolding.
.fluvie/

# Dart/Flutter build output.
.dart_tool/
build/
''';

/// The starter composition: one scene, a gradient background, an animated title.
///
/// The entry point is a top-level `Video build()`, the convention `fluvie
/// render` and `fluvie preview` look for. `--entry` names a different one.
///
/// The body below is kept byte-identical to the docregions in
/// `examples/gallery/lib/starter/starter_video.dart`, which is the compiled,
/// analyzed copy the docs excerpt. `starter_template_sync_test` fails if they
/// drift, so a reader never sees a starter that differs from the scaffolded one.
String starterCompositionSource({String fileName = 'example_video.dart'}) =>
    '''
// A starter Fluvie video: one scene, a gradient background, an animated title.
//
// Preview it:  fluvie preview ./lib/$fileName
// Render it:   fluvie render ./lib/$fileName --out ${fileName.replaceAll('.dart', '')}.mp4

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// Builds the starter composition: a 4 second square clip with a title that
/// fades and pops in. You describe what the video is; Fluvie decides when
/// everything happens.
Video build() {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        children: [
          const Text(
            'Hello, Fluvie',
            style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
''';
