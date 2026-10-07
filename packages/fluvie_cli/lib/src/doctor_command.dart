import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/ffmpeg/ffmpeg_cache.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/project_inspection.dart';
import 'package:pub_semver/pub_semver.dart';

/// Read-only authoring environment diagnostics; never installs or rewrites files.
final class DoctorCommand {
  /// Creates a doctor with injectable process and cache boundaries.
  DoctorCommand({
    ProcessRunner runner = const IoProcessRunner(),
    Map<String, String>? environment,
    FfmpegCache? cache,
    // ignore: prefer_initializing_formals — retain the public injection name.
  }) : _runner = runner,
       _environment = environment ?? Platform.environment,
       _cache = cache ?? FfmpegCache(environment: environment);

  final ProcessRunner _runner;
  final Map<String, String> _environment;
  final FfmpegCache _cache;

  /// Options for `fluvie doctor`.
  static ArgParser buildParser() => ArgParser()
    ..addFlag('json', negatable: false, help: 'Print a structured environment report.')
    ..addOption('project', help: 'Inspect this project (defaults to the nearest pubspec).')
    ..addOption('toolchain', defaultsTo: 'managed', allowed: ['managed', 'system'])
    ..addOption('ffmpeg', help: 'Check an explicit FFmpeg executable.')
    ..addOption('ffprobe', help: 'Check an explicit ffprobe executable.');

  /// Reports diagnostics and returns 1 only for blocking setup problems.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    if (args.rest.isNotEmpty) {
      err.writeln('doctor takes options only.\n${buildParser().usage}');
      return 64;
    }
    final checks = <Map<String, Object?>>[];
    try {
      final sdk = await _runner.run('flutter', const ['--version', '--machine']);
      if (sdk.exitCode != 0) {
        checks.add(
          _check(
            'flutter',
            'error',
            'Flutter could not run.',
            fix: 'Install Flutter and put flutter on PATH.',
            details: {'stderr': sdk.stderr},
          ),
        );
      } else {
        final version = jsonDecode(sdk.stdout) as Map<String, Object?>;
        final flutter = Version.parse(version['frameworkVersion']! as String);
        final dart = Version.parse((version['dartSdkVersion']! as String).split(' ').first);
        final compatible = flutter >= Version(3, 44, 0) && dart >= Version(3, 12, 0);
        checks.add(
          _check(
            'flutter',
            compatible ? 'ok' : 'error',
            compatible
                ? 'Flutter and Dart meet Fluvie requirements.'
                : 'Fluvie requires Flutter >=3.44 and Dart >=3.12.',
            fix: compatible ? null : 'Select a Flutter SDK with Dart 3.12 or newer.',
            details: {'version': version},
          ),
        );
      }
    } on Object catch (error) {
      checks.add(
        _check(
          'flutter',
          'error',
          'Flutter version check failed: $error',
          fix: 'Install Flutter and put flutter on PATH.',
        ),
      );
    }
    final requested = args.option('project');
    final project = findPubspecDirectory(requested ?? Directory.current.path);
    if (project == null) {
      checks.add(
        _check(
          'project',
          requested == null ? 'info' : 'error',
          'No pubspec.yaml found.',
          fix: 'Run from a Flutter project or pass --project <directory>.',
        ),
      );
    } else {
      try {
        final config = findPackageConfiguration(project);
        final packages = resolvedPackageNames(config);
        final hasFluvie = packages.contains('fluvie');
        checks.add(
          _check(
            'project',
            hasFluvie ? 'ok' : 'error',
            hasFluvie ? 'Fluvie runtime is resolved.' : 'Fluvie runtime is not resolved.',
            fix: hasFluvie ? null : 'Run flutter pub add fluvie, then flutter pub get.',
            details: {
              'directory': project,
              'packageConfig': config?.path,
              'resolvedPackages': packages.toList()..sort(),
            },
          ),
        );
        // Kept distinct for readable independent environment checks.
        // ignore: cascade_invocations
        checks.add(
          _check(
            'capture_support',
            'ok',
            'The CLI manages capture support outside your project.',
            details: {
              'flutterTestInProject': packages.contains('flutter_test'),
              'consumerTestDependencyRequired': false,
            },
          ),
        );
      } on Object catch (error) {
        checks.add(
          _check(
            'project',
            'error',
            'Cannot read project resolution: $error',
            fix: 'Check pubspec.yaml and run flutter pub get.',
          ),
        );
      }
    }
    try {
      final pair = await ensureFfmpegToolchain(
        _runner,
        binary: args.option('ffmpeg'),
        probeBinary: args.option('ffprobe'),
        mode: args.option('toolchain')!,
        allowDownload: false,
        environment: _environment,
        cache: _cache,
      );
      checks
        ..add(
          _check('media_tools', 'ok', 'FFmpeg and ffprobe are available.', details: pair.toJson()),
        )
        ..addAll(await _capabilities(pair));
    } on CliFailure catch (error) {
      final custom =
          args.option('ffmpeg') != null ||
          args.option('ffprobe') != null ||
          _environment['FLUVIE_FFMPEG'] != null ||
          _environment['FLUVIE_FFPROBE'] != null ||
          args.option('toolchain') == 'system';
      checks.add(
        _check(
          'media_tools',
          custom ? 'error' : 'info',
          error.message,
          fix: custom
              ? 'Fix the named executables or use --toolchain managed.'
              : 'The first render installs the managed pair; run fluvie ffmpeg install to warm it now.',
          details: {
            'ffmpeg': _cache.binaryPath,
            'ffprobe': _cache.probePath,
            'automaticInstall': !custom,
          },
        ),
      );
    } on Object catch (error) {
      checks.add(
        _check(
          'media_tools',
          'error',
          'Cannot inspect native tools: $error',
          fix: 'Run fluvie ffmpeg install or select an explicit toolchain.',
        ),
      );
    }
    final ok = !checks.any((check) => check['status'] == 'error');
    final report = {'schemaVersion': 1, 'ok': ok, 'checks': checks};
    if (args.flag('json')) {
      out.writeln(const JsonEncoder.withIndent('  ').convert(report));
    } else {
      for (final check in checks) {
        out.writeln('${check['status']}: ${check['id']}: ${check['message']}');
        if (check['fix'] != null) out.writeln('  ${check['fix']}');
      }
    }
    return ok ? 0 : 1;
  }

  Future<List<Map<String, Object?>>> _capabilities(FfmpegToolchain pair) async {
    final checks = <Map<String, Object?>>[];
    for (final kind in const ['encoders', 'decoders']) {
      final expected = kind == 'encoders'
          ? const ['libx264', 'aac', 'pcm_s16le', 'libvpx-vp9', 'prores_ks']
          : const ['libvpx-vp9'];
      try {
        final result = await _runner.run(pair.ffmpegPath, ['-hide_banner', '-$kind']);
        if (result.exitCode != 0) throw StateError(result.stderr);
        final available = RegExp(
          r'^\s*[A-Z.]{6}\s+(\S+)',
          multiLine: true,
        ).allMatches(result.stdout).map((match) => match[1]!).toSet();
        final missing = expected.where((name) => !available.contains(name)).toList();
        checks.add(
          _check(
            'media_$kind',
            missing.isEmpty ? 'ok' : 'info',
            missing.isEmpty
                ? 'Common Fluvie $kind are available.'
                : 'Some presets need unavailable $kind: ${missing.join(', ')}.',
            fix: missing.isEmpty
                ? null
                : 'Use the managed toolchain, select supported export settings, or provide a custom renderer.',
            details: {
              'availableCommon': expected.where(available.contains).toList(),
              'missingCommon': missing,
            },
          ),
        );
      } on Object catch (error) {
        checks.add(
          _check(
            'media_$kind',
            'info',
            'Could not inspect FFmpeg $kind: $error',
            fix: 'Check this toolchain supports the codecs used by your composition.',
          ),
        );
      }
    }
    return checks;
  }

  static Map<String, Object?> _check(
    String id,
    String status,
    String message, {
    String? fix,
    Map<String, Object?>? details,
  }) => {
    'id': id,
    'status': status,
    'message': message,
    'fix': ?fix,
    'details': ?details,
  };
}
