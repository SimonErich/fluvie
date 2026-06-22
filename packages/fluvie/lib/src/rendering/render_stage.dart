import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/render_phase.dart';

/// Runs [body], stamping [phase] onto any [FluvieRenderException] it throws (when
/// not already stamped) so the failure records which render stage broke.
///
/// The exact exception subtype and stack trace are preserved (a
/// `FluvieEncodeException` keeps its exit code and stderr), so callers still
/// catch and inspect it as before — now with `stage` populated.
Future<T> runStage<T>(RenderPhase phase, Future<T> Function() body) async {
  try {
    return await body();
  } on FluvieRenderException catch (error) {
    error.stage ??= phase;
    rethrow;
  }
}
