// Epic 9.4 acceptance (WI-21, untagged): the bundled ripple shader renders
// byte-identically off-screen (the capture path) and a missing asset surfaces a
// typed error naming it through the pre-load loader. The golden lives in
// goldens_shader_test.dart; this proves capture-safety and the error contract.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/effects/shader_effect.dart';
import 'package:fluvie/src/animation/runtime/shader_loader.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';

Future<Uint8List> _capture(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage();
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('the ripple shader renders byte-identically off-screen (capture-safe)', (
    tester,
  ) async {
    late ui.FragmentShader shader;
    await tester.runAsync(() async {
      shader = await const FragmentProgramShaderLoader().load('shaders/ripple.frag');
    });
    final effect = ShaderEffect(shaderName: 'shaders/ripple.frag', shader: shader);

    final key = GlobalKey();
    Widget tree() => RepaintBoundary(
      key: key,
      child: SizedBox(
        width: 64,
        height: 64,
        child: effect.build(const ColoredBox(color: Color(0xFF12243A)), 0.5),
      ),
    );

    await tester.pumpWidget(Center(child: tree()));
    late final Uint8List first;
    await tester.runAsync(() async {
      first = await _capture(tester, key);
    });

    await tester.pumpWidget(Center(child: tree()));
    late final Uint8List second;
    await tester.runAsync(() async {
      second = await _capture(tester, key);
    });

    expect(first.any((byte) => byte != 0), isTrue, reason: 'the shader frame was blank');
    expect(second, equals(first), reason: 'two off-screen captures must be byte-identical');
  });

  test('a missing asset surfaces a FluvieRenderException naming it (the pre-load path)', () async {
    Object? caught;
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      try {
        await const FragmentProgramShaderLoader().load('missing.frag');
      } on Object catch (error) {
        caught = error;
      }
    });
    expect(caught, isA<FluvieRenderException>());
    expect((caught! as FluvieRenderException).message, contains('missing.frag'));
  });
}
