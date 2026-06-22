import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_encode_exception.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/render_phase.dart';
import 'package:fluvie/src/rendering/render_stage.dart';

void main() {
  group('runStage', () {
    test('returns the body result on success', () async {
      expect(await runStage(RenderPhase.capturing, () async => 42), 42);
    });

    test('stamps the phase on a thrown FluvieRenderException', () async {
      await expectLater(
        runStage(RenderPhase.capturing, () async => throw FluvieRenderException('nope')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.stage, 'stage', RenderPhase.capturing),
        ),
      );
    });

    test('preserves the subtype and its detail', () async {
      await expectLater(
        runStage(
          RenderPhase.encoding,
          () async => throw FluvieEncodeException('ffmpeg failed', exitCode: 1, stderrTail: 'tail'),
        ),
        throwsA(
          isA<FluvieEncodeException>()
              .having((e) => e.stage, 'stage', RenderPhase.encoding)
              .having((e) => e.exitCode, 'exitCode', 1)
              .having((e) => e.toString(), 'toString', contains('[encoding]')),
        ),
      );
    });

    test('does not overwrite an already-stamped stage', () async {
      await expectLater(
        runStage(
          RenderPhase.encoding,
          () => runStage(
            RenderPhase.capturing,
            () async => throw FluvieRenderException('inner'),
          ),
        ),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.stage, 'stage', RenderPhase.capturing),
        ),
      );
    });

    test('passes a non-Fluvie error through unstamped', () async {
      await expectLater(
        runStage(RenderPhase.capturing, () async => throw ArgumentError('x')),
        throwsArgumentError,
      );
    });

    test('toString includes the stage when set, omits it when null', () {
      expect(FluvieRenderException('boom').toString(), 'FluvieRenderException: boom');
      final stamped = FluvieRenderException('boom')..stage = RenderPhase.capturing;
      expect(stamped.toString(), 'FluvieRenderException [capturing]: boom');
    });
  });
}
