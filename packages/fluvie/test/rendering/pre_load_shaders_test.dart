import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Color, ColoredBox, DefaultTextStyle, SizedBox, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/animation/animation.dart';
import 'package:fluvie/src/animation/runtime/shader_loader.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/rendering/pre_load_shaders.dart';

const _box = ColoredBox(color: Color(0xFF223344));

/// Records every asset it was asked for, so a test can assert the pass loads
/// each one exactly once and never touches the bundle.
final class _RecordingLoader implements ShaderLoader {
  _RecordingLoader(this._program, {this.failOn});

  final ui.FragmentProgram _program;
  final String? failOn;
  final asked = <String>[];

  @override
  Future<ui.FragmentProgram> load(String asset) async {
    asked.add(asset);
    if (asset == failOn) {
      throw FluvieRenderException('Could not load fragment shader "$asset".');
    }
    return _program;
  }
}

void main() {
  late ui.FragmentProgram program;

  setUpAll(() async {
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
    });
  });

  test('compiles every shader a composition paints, once per asset', () async {
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(30),
          children: [
            _box.animate([Animation.shader('shaders/ripple.frag')]),
            _box.animate([Animation.shader('shaders/ripple.frag')]),
            SizedBox(
              child: _box.animate([Animation.shader('shaders/other.frag')]),
            ),
          ],
        ),
      ],
    );
    final loader = _RecordingLoader(program);

    final programs = await preLoadCompositionShaders(composition: video, loader: loader);

    expect(programs.keys, {'shaders/ripple.frag', 'shaders/other.frag'});
    expect(loader.asked, hasLength(2), reason: 'one compile per asset, not per element');
  });

  test('a composition with no shader compiles nothing', () async {
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(30),
          children: [
            _box.animate([Animation.fadeIn()]),
          ],
        ),
      ],
    );
    final loader = _RecordingLoader(program);

    expect(await preLoadCompositionShaders(composition: video, loader: loader), isEmpty);
    expect(loader.asked, isEmpty);
  });

  test('a Video behind a wrapper the walk cannot descend warms nothing', () async {
    // DefaultTextStyle.merge returns a Builder, a plain StatelessWidget, which
    // compositionVideo cannot descend (it follows only ProxyWidget and
    // SingleChildRenderObjectWidget). renderVideo applies exactly that wrapper
    // when a host names a font family, so warming from the wrapped composition
    // silently found no Video and no shader ever compiled.
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(30),
          children: [
            _box.animate([Animation.shader('shaders/ripple.frag')]),
          ],
        ),
      ],
    );
    final wrapped = DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'Roboto'),
      child: video,
    );
    final loader = _RecordingLoader(program);

    expect(
      await preLoadCompositionShaders(composition: wrapped, loader: loader),
      isEmpty,
      reason: 'the walk genuinely cannot see through a Builder',
    );
    // So the render entry points must warm from the resolved Video itself.
    expect(
      (await preLoadCompositionShaders(composition: video, loader: loader)).keys,
      {'shaders/ripple.frag'},
    );
  });

  test('a composition that wraps no Video compiles nothing', () async {
    final loader = _RecordingLoader(program);

    expect(await preLoadCompositionShaders(composition: _box, loader: loader), isEmpty);
    expect(loader.asked, isEmpty);
  });

  test('a bad asset fails the pre-pass by name, not at paint', () async {
    final video = Video(
      scenes: [
        Scene(
          duration: const Time.frames(30),
          children: [
            _box.animate([Animation.shader('shaders/missing.frag')]),
          ],
        ),
      ],
    );
    final loader = _RecordingLoader(program, failOn: 'shaders/missing.frag');

    await expectLater(
      preLoadCompositionShaders(composition: video, loader: loader),
      throwsA(
        isA<FluvieRenderException>().having(
          (error) => error.message,
          'message',
          contains('shaders/missing.frag'),
        ),
      ),
    );
  });

  test('preLoadShaders takes a bare asset set for a host that already knows it', () async {
    final loader = _RecordingLoader(program);

    final programs = await preLoadShaders(const ['a.frag', 'b.frag', 'a.frag'], loader: loader);

    expect(programs.keys, {'a.frag', 'b.frag'});
    expect(loader.asked, ['a.frag', 'b.frag']);
  });
}
