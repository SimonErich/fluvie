import 'dart:ui' as ui;

import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// Loads a `FragmentShader` from a bundled `.frag` asset.
///
/// This is the boundary between the experimental shader effect and `dart:ui`'s
/// `FragmentProgram`. Loading is asynchronous IO, so the program is fetched
/// once **before frame 0** (like media pre-resolution) and the warm shader is
/// handed to the painter, which paints synchronously during capture — no
/// async-in-frame, so the determinism contract holds.
///
/// The default implementation is [FragmentProgramShaderLoader]; tests inject a
/// fake so the unit path never touches the asset bundle.
// ignore: one_member_abstracts — the shader-load boundary stays mockable behind a fake.
abstract interface class ShaderLoader {
  /// Loads the shader at [asset] (the `flutter: shaders:` key, e.g.
  /// `shaders/ripple.frag`).
  ///
  /// Throws a [FluvieRenderException] naming [asset] when it is missing or
  /// cannot be compiled.
  Future<ui.FragmentShader> load(String asset);
}

/// The real [ShaderLoader]: compiles the asset via `FragmentProgram.fromAsset`
/// and returns a fresh shader instance from the program.
///
/// A missing or invalid asset surfaces as a [FluvieRenderException] naming the
/// asset, so the failure points at the author's `shaders:` registration rather
/// than leaking a raw `dart:ui` error.
final class FragmentProgramShaderLoader implements ShaderLoader {
  /// Creates the default asset-backed loader.
  const FragmentProgramShaderLoader();

  @override
  Future<ui.FragmentShader> load(String asset) async {
    try {
      final program = await ui.FragmentProgram.fromAsset(asset);
      return program.fragmentShader();
    } on Object catch (error) {
      throw FluvieRenderException(
        'Could not load fragment shader "$asset": $error. Check it is listed '
        'under `flutter: shaders:` in pubspec.yaml and is valid GLSL.',
      );
    }
  }
}
