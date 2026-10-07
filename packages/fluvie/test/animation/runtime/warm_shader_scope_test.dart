import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/warm_shader_scope.dart';

void main() {
  late ui.FragmentProgram program;

  setUpAll(() async {
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      program = await ui.FragmentProgram.fromAsset('shaders/ripple.frag');
    });
  });

  testWidgets('serves the program the pre-pass compiled', (tester) async {
    late WarmShaderScope? found;
    await tester.pumpWidget(
      WarmShaderScope(
        programs: {'shaders/ripple.frag': program},
        child: Builder(
          builder: (context) {
            found = WarmShaderScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(found!.programFor('shaders/ripple.frag'), same(program));
  });

  testWidgets('an asset nothing warmed reads as absent, not as an error', (tester) async {
    late WarmShaderScope? found;
    await tester.pumpWidget(
      WarmShaderScope(
        programs: {'shaders/ripple.frag': program},
        child: Builder(
          builder: (context) {
            found = WarmShaderScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // The painter is what reports it, naming the asset; the scope just says no.
    expect(found!.programFor('shaders/absent.frag'), isNull);
  });

  testWidgets('no scope above means no lookup, never a throw', (tester) async {
    late WarmShaderScope? found;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = WarmShaderScope.maybeOf(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(found, isNull);
  });

  test('a re-warmed set notifies dependents; the same set does not', () {
    // Asserted on the widget directly: pumping rebuilds the whole subtree, so a
    // widget test cannot observe updateShouldNotify on its own.
    final programs = {'shaders/ripple.frag': program};
    WarmShaderScope scope(Map<String, ui.FragmentProgram> map) =>
        WarmShaderScope(programs: map, child: const SizedBox.shrink());

    expect(scope(programs).updateShouldNotify(scope(programs)), isFalse);
    expect(
      scope({'shaders/ripple.frag': program}).updateShouldNotify(scope(programs)),
      isTrue,
      reason: 'a fresh warm pass is a fresh map, and dependents must re-derive',
    );
  });
}
