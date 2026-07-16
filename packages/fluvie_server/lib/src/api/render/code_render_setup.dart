import 'package:fluvie_cli/fluvie_cli.dart'
    show StagedHarness, fileHarnessSource, resolveProjectDir, stageHarness, uniqueStageId;
import 'package:fluvie_server/src/api/render/code_import_policy.dart';
import 'package:fluvie_server/src/api/render/render_runner.dart';

/// How long an untrusted snippet's capture may run before `flutter test` kills
/// it, under the runner's own wall-clock ceiling.
const Duration codeRenderTimeout = Duration(minutes: 6);

/// Stages an untrusted Playground snippet for capture under [projectDir].
///
/// Enforces the import allowlist FIRST (throwing [CodeImportException] before
/// touching the disk), then writes the snippet to `input.dart` and a generated
/// harness beside it in a fresh unique directory under
/// `<projectDir>/.fluvie_playground/`. The harness statically imports the
/// snippet so `flutter test` JIT-compiles it.
///
/// The harness is the same one the CLI generates for a local file render, with
/// two differences that are the whole untrusted story: the directory is unique
/// and deleted afterward (two submissions must never share one), and the test
/// carries a bounded timeout instead of `Timeout.none` so a runaway `build()`
/// is killed.
///
/// Per-render isolation is by directory only here. Per-render container
/// isolation (gVisor or equivalent) is the recommended hardening before
/// exposing this to anonymous public traffic, and is out of scope.
StagedHarness stageCodeRender({required String projectDir, required String code}) {
  final disallowed = disallowedImports(code);
  if (disallowed.isNotEmpty) throw CodeImportException(disallowed);

  return stageHarness(
    projectDir: projectDir,
    relativeDir: '.fluvie_playground/${uniqueStageId()}',
    extraFiles: {'input.dart': code},
    harnessSource: fileHarnessSource(
      targetImport: 'input.dart',
      timeout: codeRenderTimeout,
    ),
  );
}

/// Stages a code render under the render project (auto-discovered from
/// [renderProject]), mapping a disallowed import to a client-safe
/// [RenderFailure] — the defensive, in-runner half of the import allowlist the
/// handler already gated.
StagedHarness stageCodeRenderOrFail({required String? renderProject, required String code}) {
  try {
    return stageCodeRender(
      projectDir: resolveProjectDir(project: renderProject),
      code: code,
    );
  } on CodeImportException catch (error) {
    throw RenderFailure(error.message);
  }
}
