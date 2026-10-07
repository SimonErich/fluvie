import 'dart:ui' as ui;

import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// Loads a `FragmentProgram` from a bundled `.frag` asset.
///
/// This is the boundary between the experimental shader effect and `dart:ui`'s
/// `FragmentProgram`. Loading is asynchronous IO, so the program is compiled
/// once **before frame 0** (like media pre-resolution) and published to the
/// tree, which paints synchronously during capture — no async-in-frame, so the
/// capture model holds.
///
/// It yields the *program*, not a shader: a `FragmentShader` carries mutable
/// uniform slots that paint rewrites every frame, so two elements sharing one
/// instance would overwrite each other's uniforms. Each element derives its own
/// shader from the shared program instead.
///
/// The default implementation is [FragmentProgramShaderLoader]; tests inject a
/// fake so the unit path never touches the asset bundle.
// ignore: one_member_abstracts — the shader-load boundary stays mockable behind a fake.
abstract interface class ShaderLoader {
  /// Compiles the shader program at [asset] (the `flutter: shaders:` key, e.g.
  /// `shaders/ripple.frag`).
  ///
  /// Throws a [FluvieRenderException] naming [asset] when it is missing or
  /// cannot be compiled.
  Future<ui.FragmentProgram> load(String asset);
}

/// The real [ShaderLoader]: compiles the asset via `FragmentProgram.fromAsset`.
///
/// A missing or invalid asset surfaces as a [FluvieRenderException] naming the
/// asset, so the failure points at the author's `shaders:` registration rather
/// than leaking a raw `dart:ui` error.
final class FragmentProgramShaderLoader implements ShaderLoader {
  /// Creates the default asset-backed loader.
  const FragmentProgramShaderLoader();

  @override
  Future<ui.FragmentProgram> load(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset(asset);
    } on Object catch (error) {
      // A fluvie-bundled shader keeps one canonical key everywhere, but the
      // bundle indexes it under `packages/fluvie/` when the render runs
      // inside an app that depends on fluvie. Same fallback the .cube
      // loader applies.
      if (!asset.startsWith('packages/')) {
        try {
          return await ui.FragmentProgram.fromAsset('packages/fluvie/$asset');
        } on Object {
          // The original error names the asset as authored.
        }
      }
      throw FluvieRenderException(
        'Could not load fragment shader "$asset": $error. Check it is listed '
        'under `flutter: shaders:` in pubspec.yaml and is valid GLSL.',
      );
    }
  }
}
