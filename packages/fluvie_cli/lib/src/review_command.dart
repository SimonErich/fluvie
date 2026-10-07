// Public injection names remain stable while their backing fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/composition_fingerprint.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/review_page.dart';
import 'package:fluvie_cli/src/review_quality.dart';
import 'package:fluvie_cli/src/review_workflow.dart';
import 'package:path/path.dart' as p;

/// Mounted preparation and sample boundary, injectable without a Flutter engine.
typedef ReviewCapture =
    Future<Map<String, Object?>> Function(FileTarget target, ArgResults args, String outputDir);

/// Static validation, sampled pictures, fresh-mount and seek-order checks, and optional export
/// verification in one report. The authored Dart source is never modified.
final class ReviewCommand {
  /// Creates a review with optional engine and static-analysis boundaries.
  ReviewCommand({
    ProcessRunner runner = const IoProcessRunner(),
    Future<Map<String, Object?>> Function(FileTarget)? validate,
    ReviewCapture? capture,
    ReviewCapture? render,
  }) : _runner = runner,
       _validate = validate,
       _capture = capture,
       _render = render;

  final ProcessRunner _runner;
  final Future<Map<String, Object?>> Function(FileTarget)? _validate;
  final ReviewCapture? _capture;
  final ReviewCapture? _render;

  /// Review options. Empty samples select representative mounted timeline frames.
  static ArgParser buildParser() {
    final parser = ArgParser()
      ..addOption('entry', defaultsTo: 'build', help: 'Top-level Video builder.')
      ..addMultiOption(
        'samples',
        help: 'Absolute sample frame indexes (comma-separated, at most 24).',
      )
      ..addFlag(
        'determinism',
        negatable: false,
        help: 'Compare reverse seeks and a fresh mount, re-evaluating the entry factory.',
      )
      ..addFlag(
        'render',
        negatable: false,
        help: 'Render and verify the complete video or requested draft prefix.',
      )
      ..addFlag(
        'strict-decode',
        negatable: false,
        help: 'With --render, decode the whole output to detect corruption.',
      )
      ..addOption(
        'out-dir',
        help: 'Review report and sample directory (default: build/fluvie/<video>.review).',
      )
      ..addFlag('json', negatable: false, help: 'Emit one complete structured review report.')
      ..addFlag(
        'strict-quality',
        negatable: false,
        help: 'Fail on quality warnings not explicitly allowed.',
      )
      ..addMultiOption(
        'allow-quality',
        allowed: reviewQualityCodes.toList(),
        help: 'Allow intentional quality findings; retain them in the report.',
      );
    addSharedRenderOptions(parser);
    return parser;
  }

  /// Returns 1 for failed validation, determinism, or output verification.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.length != 1 || !args.rest.single.endsWith('.dart')) {
      err.writeln('review requires one Dart composition.');
      return 64;
    }
    final indexes = args.multiOption('samples').map(int.tryParse).toList();
    if (indexes.length > 24 ||
        indexes.any((frame) => frame == null || frame < 0) ||
        (args.flag('strict-decode') && !args.flag('render'))) {
      err.writeln(
        'Use up to 24 non-negative --samples indexes. --strict-decode requires --render.',
      );
      return 64;
    }
    final workflow = ReviewWorkflow(runner: _runner, err: err);
    final report = <String, Object?>{'schemaVersion': 1, 'ok': false};
    String? directory;
    var stage = 'validate';
    try {
      validateRenderAdapters(args);
      validateFrames(args.option('frames'));
      validateExportFlags(args);
      if (args.option('renderer') != null) {
        throw const UsageFailure(
          'Review uses the managed composition engine. Use render for a custom renderer.',
        );
      }
      final target = resolveFileTarget(
        arg: args.rest.single,
        entry: args.option('entry')!,
        project: args.option('project'),
      );
      report['source'] = target.path;
      report['sourceRevision'] = (await fingerprintComposition(target.projectDir)).digest;
      report['backend'] = args.flag('enable-impeller') ? 'flutter-test-impeller' : 'flutter-test';
      directory = p.absolute(
        args.option('out-dir') ??
            p.join(
              target.projectDir,
              'build/fluvie',
              '${p.basenameWithoutExtension(target.path)}.review',
            ),
      );
      final validation = await (_validate ?? workflow.validate)(target);
      report.addAll({
        'ok': validation['ok'] == true,
        'validation': validation,
        'stage': stage,
      });
      if (report['ok'] == true) {
        stage = 'prepare';
        report.addAll(await (_capture ?? workflow.capture)(target, args, directory));
        final check = report['determinism'];
        if (check is Map<String, Object?> && check['ok'] == false) report['ok'] = false;
        if (args.flag('render')) {
          stage = 'render';
          final artifact = await (_render ?? workflow.render)(target, args, directory);
          report['artifact'] = artifact;
          final audio = artifact['audioQuality'] as Map<String, Object?>?;
          if (audio != null) {
            final quality = report['quality'] as Map<String, Object?>? ?? const {};
            report['quality'] = {
              ...quality,
              'audio': audio,
              'findings': [...?(quality['findings'] as List?), ...?(audio['findings'] as List?)],
            };
          }
          final verified = artifact['verification'];
          if (verified is Map<String, Object?> && verified['ok'] == false) report['ok'] = false;
        }
        if ((await fingerprintComposition(target.projectDir)).digest != report['sourceRevision']) {
          throw const CliFailure('Source changed during review. Retry against a stable revision.');
        }
        report['stage'] = 'complete';
        final quality = report['quality'] as Map<String, Object?>? ?? {'findings': <Object?>[]};
        report['quality'] = evaluateReviewQuality(
          quality,
          allowed: args.multiOption('allow-quality').toSet(),
          strict: args.flag('strict-quality'),
        );
        if ((report['quality']! as Map<String, Object?>)['ok'] == false) report['ok'] = false;
      }
      await _publish(report, directory, args, out);
      return report['ok'] == true ? 0 : 1;
    } on UsageFailure catch (error) {
      err.writeln(error.message);
      return 64;
    } on Object catch (error) {
      report.addAll({
        'ok': false,
        'stage': stage,
        'error': {
          'code': 'review_failed',
          'message': '$error',
          'remedy': 'Correct the reported source, timing or resource failure and review again.',
        },
      });
      if (directory != null) {
        await _publish(report, directory, args, out);
      } else if (args.flag('json')) {
        out.writeln(jsonEncode(report));
      } else {
        err.writeln('Review failed during $stage: $error');
      }
      return 1;
    }
  }

  Future<void> _publish(
    Map<String, Object?> report,
    String directory,
    ArgResults args,
    StringSink out,
  ) async {
    final path = p.join(directory, 'review.json');
    report['reportPath'] = path;
    report['pagePath'] = await writeReviewPage(report, directory);
    await atomicWrite(path, const JsonEncoder.withIndent('  ').convert(report));
    if (args.flag('json') || args.flag('machine')) {
      out.writeln(jsonEncode({if (args.flag('machine')) 'event': 'review', ...report}));
    } else {
      out.writeln('Review ${report['ok'] == true ? 'passed' : 'failed'}: $path');
      if (report['error'] case final Map<String, Object?> error) out.writeln(error['message']);
    }
  }
}
