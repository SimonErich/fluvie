// Public capture injection retains its descriptive name.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/composition_fingerprint.dart';
import 'package:fluvie_cli/src/export_flags.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/file_target.dart';
import 'package:fluvie_cli/src/native_render_worker.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_pipeline.dart';
import 'package:fluvie_cli/src/review_quality.dart';
import 'package:fluvie_cli/src/review_workflow.dart';
import 'package:fluvie_cli/src/stage_harness.dart';
import 'package:fluvie_cli/src/workspace_inputs.dart';
import 'package:path/path.dart' as p;

part 'workspace_session_capture.dart';

/// Source-aware frame, review and export session shared by a browser and agents.
final class WorkspaceSession {
  /// Uses the managed worker by default. [capture] replaces the engine transport
  /// for hosts that already own an engine; it must implement the render receipt
  /// protocol and write only inside the invocation's output directory.
  WorkspaceSession({
    required this.target,
    required this.directory,
    required this.toolchain,
    required this.err,
    this.runner = const IoProcessRunner(),
    this.impeller = false,
    this.workerStartupTimeout = const Duration(minutes: 5),
    this.workerRequestTimeout = const Duration(minutes: 5),
    Future<Map<String, Object?>> Function(Map<String, Object?>)? capture,
  }) : _capture = capture {
    if (workerStartupTimeout <= Duration.zero || workerRequestTimeout <= Duration.zero) {
      throw ArgumentError('Worker startup and request timeouts must be positive.');
    }
  }

  /// Original Dart entry and dependency project.
  final FileTarget target;

  /// Owned results root, normally under the project's ignored build directory.
  final Directory directory;

  /// One resolved FFmpeg pair used by every request.
  final FfmpegToolchain toolchain;

  /// Diagnostic output, separate from structured results.
  final StringSink err;

  /// Encoder and receipt-verification process seam.
  final ProcessRunner runner;

  /// Selects the same Impeller backend for all worker requests.
  final bool impeller;

  /// Ready deadline including staging and Flutter compilation. Default: five minutes.
  final Duration workerStartupTimeout;

  /// Engine request deadline, separate from startup. Default: five minutes.
  final Duration workerRequestTimeout;
  final Future<Map<String, Object?>> Function(Map<String, Object?>)? _capture;
  NativeRenderWorker? _worker;
  String _metadata = '';
  String? _revision;
  Map<String, Object?>? _lastFrame;
  bool _busy = false;
  bool _closed = false;

  /// Current identity. A job refreshes the revision before touching the engine.
  Map<String, Object?> get status => {
    'schemaVersion': 1,
    'source': target.path,
    'sourceRevision': _revision,
    'backend': impeller ? 'flutter-test-impeller' : 'flutter-test',
    'busy': _busy,
    'closed': _closed,
    'workerPid': _worker?.process.pid,
    'startupMilliseconds': _worker?.startupMilliseconds,
    'startupTimeoutSeconds': workerStartupTimeout.inSeconds,
    'requestTimeoutSeconds': workerRequestTimeout.inSeconds,
    'toolchain': toolchain.toJson(),
  };

  /// Runs a single validated job. The caller serializes access to the session.
  /// Results are withheld if source inputs change during capture or encoding.
  Future<Map<String, Object?>> execute(Map<String, Object?> input) async {
    final options = _workspaceOptions(input);
    if (_closed || _busy) throw const CliFailure('The workspace is closed or busy.');
    _busy = true;
    final watch = Stopwatch()..start();
    try {
      final metadata = workspaceInputs(target.projectDir);
      if (metadata != _metadata || _revision == null) {
        await _worker?.close();
        _worker = null;
        final fingerprint = await fingerprintComposition(target.projectDir);
        _revision = fingerprint.digest;
        _metadata = workspaceInputs(target.projectDir);
        if (_metadata != metadata) {
          throw const CliFailure('Source changed during preparation. Retry.');
        }
      }
      final expected = input['sourceRevision'];
      if (expected != null && expected != _revision) {
        throw const CliFailure(
          'Source revision changed. Inspect status and retry against the new revision.',
        );
      }
      final revision = _revision!;
      final job = Directory(p.join(directory.absolute.path, 'jobs', uniqueStageId()))
        ..createSync(recursive: true);
      final result = await _executeCapture(options, job);
      if (_metadata != workspaceInputs(target.projectDir)) {
        throw const CliFailure('Source changed while rendering. This result is stale; retry.');
      }
      result.addAll({
        'schemaVersion': 1,
        'sourceRevision': revision,
        'backend': impeller ? 'flutter-test-impeller' : 'flutter-test',
        'elapsedMilliseconds': watch.elapsedMilliseconds,
        'startupMilliseconds': _worker?.startupMilliseconds,
        'workerPid': _worker?.process.pid,
      });
      if (options['operation'] == 'frame') {
        if (_lastFrame != null) result['comparison'] = _lastFrame;
        _lastFrame = Map.unmodifiable({...result}..remove('comparison'));
      }
      await atomicWrite(p.join(job.path, 'result.json'), jsonEncode(result));
      return result;
    } finally {
      _busy = false;
    }
  }

  /// Reaps the owned worker. The result directory remains available for review.
  Future<void> close() async {
    _closed = true;
    await _worker?.close();
    _worker = null;
  }
}

Map<String, Object?> _workspaceOptions(Map<String, Object?> input) {
  const allowed = {
    'operation',
    'frameIndex',
    'frameCount',
    'reviewFrames',
    'reviewDeterminism',
    'aspect',
    'quality',
    'format',
    'sourceRevision',
    'strictQuality',
    'allowQuality',
  };
  if (input.keys.any((key) => !allowed.contains(key))) throw ArgumentError('Unknown job options.');
  final operation = input['operation'] ?? 'frame';
  if (!{'frame', 'review', 'render', 'inspect'}.contains(operation)) {
    throw ArgumentError('Use frame, review, inspect or render.');
  }
  for (final key in ['frameIndex', 'frameCount']) {
    final value = input[key];
    if (value != null && (value is! int || value < (key == 'frameCount' ? 1 : 0))) {
      throw ArgumentError(
        '$key must be a ${key == 'frameCount' ? 'positive' : 'non-negative'} integer.',
      );
    }
  }
  final samples = input['reviewFrames'];
  if (samples != null &&
      (samples is! List || samples.length > 24 || samples.any((v) => v is! int || v < 0))) {
    throw ArgumentError('Invalid reviewFrames.');
  }
  if (input['strictQuality'] != null && input['strictQuality'] is! bool) {
    throw ArgumentError('strictQuality must be boolean.');
  }
  final allow = input['allowQuality'];
  if (allow != null &&
      (allow is! List || allow.any((v) => v is! String || !reviewQualityCodes.contains(v)))) {
    throw ArgumentError('allowQuality must contain known finding codes.');
  }
  if (input['reviewDeterminism'] != null && input['reviewDeterminism'] is! bool) {
    throw ArgumentError('reviewDeterminism must be a boolean.');
  }
  for (final key in ['aspect', 'quality', 'format', 'sourceRevision']) {
    if (input[key] != null && input[key] is! String) throw ArgumentError('$key must be a string.');
  }
  return {...input, 'operation': operation};
}
