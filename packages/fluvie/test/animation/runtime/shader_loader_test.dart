import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/shader_loader.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

/// A fake satisfying the [ShaderLoader] contract without touching the asset
/// bundle, so the unit path is independent of the WI-18 spike outcome.
final class _FakeShaderLoader implements ShaderLoader {
  _FakeShaderLoader(this._shader);

  final ui.FragmentShader _shader;
  String? lastAsset;

  @override
  Future<ui.FragmentShader> load(String asset) async {
    lastAsset = asset;
    return _shader;
  }
}

void main() {
  test('the contract resolves a FragmentShader through a fake', () async {
    late ui.FragmentShader shader;
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
      shader = program.fragmentShader();
    });
    final loader = _FakeShaderLoader(shader);

    final loaded = await loader.load('shaders/ripple.frag');

    expect(loaded, same(shader));
    expect(loader.lastAsset, 'shaders/ripple.frag');
  });

  group('FragmentProgramShaderLoader (the real default)', () {
    test('loads the bundled ripple shader', () async {
      late ui.FragmentShader shader;
      await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
        shader = await const FragmentProgramShaderLoader().load('shaders/ripple.frag');
      });
      expect(shader, isA<ui.FragmentShader>());
    });

    test('a missing asset throws FluvieRenderException naming the asset', () async {
      Object? caught;
      await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
        try {
          await const FragmentProgramShaderLoader().load('shaders/does_not_exist.frag');
        } on Object catch (error) {
          caught = error;
        }
      });
      expect(caught, isA<FluvieRenderException>());
      expect((caught! as FluvieRenderException).message, contains('shaders/does_not_exist.frag'));
    });
  });
}
