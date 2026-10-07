import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/asset_inventory.dart';
import 'package:fluvie_cli/src/assets_catalog_command.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/project_inspection.dart';
import 'package:fluvie_cli/src/render_pipeline.dart' show ToolchainResolver;
import 'package:fluvie_media/native.dart';
import 'package:path/path.dart' as p;

/// Recursive, factual local media and story-note discovery for authoring.
final class AssetsCommand {
  /// Creates inventory with an optional probe seam for tests or custom tools.
  AssetsCommand({
    ProcessRunner runner = const IoProcessRunner(),
    AssetProbe? probe,
    ToolchainResolver resolveToolchain = ensureFfmpegToolchain,
  })
    // Public option names are kept stable while their storage stays private.
    // ignore: prefer_initializing_formals
    : _runner = runner,
       // Public option names are kept stable while their storage stays private.
       // ignore: prefer_initializing_formals
       _probe = probe,
       // ignore: prefer_initializing_formals — preserve the public injection name.
       _resolveToolchain = resolveToolchain;

  final ProcessRunner _runner;
  final AssetProbe? _probe;
  final ToolchainResolver _resolveToolchain;

  /// Options for `fluvie assets [directory]`.
  static ArgParser buildParser() => ArgParser()
    ..addFlag('json', negatable: false, help: 'Print structured asset facts.')
    ..addOption('project', help: 'Project whose asset keys and font declarations to use.')
    ..addOption('catalog-out', help: 'Write a reusable content-bound semantic asset catalog.')
    ..addFlag(
      'contact-sheets',
      negatable: false,
      help: 'Prepare timestamped local visual evidence.',
    )
    ..addOption('evidence', help: 'Explicit JSON observations with asset/time/text/certainty.')
    ..addMultiOption(
      'transcript',
      splitCommas: false,
      help: 'Bind selected captions: asset.mp4=captions.srt (repeatable).',
    )
    ..addOption(
      'text-limit',
      defaultsTo: '8192',
      help: 'Maximum text preview bytes per file (1..1048576).',
    )
    ..addOption('toolchain', defaultsTo: 'managed', allowed: ['managed', 'system'])
    ..addOption('ffmpeg')
    ..addOption('ffprobe')
    ..addFlag(
      'download-tools',
      negatable: false,
      help: 'Install missing managed tools before probing.',
    )
    ..addFlag('download', hide: true, help: 'Alias for --download-tools.');

  /// Produces one inventory and returns 1 when a file could not be inspected.
  Future<int> execute(ArgResults args, {required StringSink out, required StringSink err}) async {
    final limit = int.tryParse(args.option('text-limit')!);
    if (args.rest.length > 1 || limit == null || limit < 1 || limit > 1048576) {
      err.writeln('assets accepts one directory and --text-limit must be 1..1048576.');
      return 64;
    }
    final project = findPubspecDirectory(
      args.option('project') ?? (args.rest.isEmpty ? Directory.current.path : args.rest.single),
    );
    final root = Directory(
      p.normalize(
        p.absolute(
          args.rest.isEmpty
              ? p.join(project ?? Directory.current.path, 'assets')
              : args.rest.single,
        ),
      ),
    );
    if (!root.existsSync()) {
      final report = {
        'schemaVersion': 1,
        'ok': false,
        'root': root.path,
        'files': <Object?>[],
        'errors': ['No asset directory at "${root.path}".'],
      };
      if (args.flag('json')) {
        out.writeln(jsonEncode(report));
      } else {
        err.writeln('No asset directory at "${root.path}".');
      }
      return 1;
    }
    final files = inventoryFiles(root);
    if (args.option('catalog-out') != null || args.flag('contact-sheets')) {
      return executeAssetsCatalog(
        args: args,
        root: root,
        project: project ?? Directory.current.path,
        runner: _runner,
        probe: _probe,
        out: out,
        err: err,
        resolveToolchain: _resolveToolchain,
      );
    }
    if (args.option('evidence') != null || args.multiOption('transcript').isNotEmpty) {
      err.writeln('Use --catalog-out to retain selected observations or transcripts.');
      return 64;
    }
    final facts = <Map<String, Object?>>[];
    final errors = <String>[];
    FfmpegMediaTools? tools;
    var probe = _probe;
    if (probe == null && files.any(needsAssetProbe)) {
      try {
        final pair = await _resolveToolchain(
          _runner,
          binary: args.option('ffmpeg'),
          probeBinary: args.option('ffprobe'),
          mode: args.option('toolchain')!,
          allowDownload: args.flag('download-tools') || args.flag('download'),
          log: err.writeln,
        );
        tools = FfmpegMediaTools(ffmpegPath: pair.ffmpegPath, ffprobePath: pair.ffprobePath);
        probe = tools.probeReport;
      } on Object catch (error) {
        errors.add(
          'Media probe unavailable: $error Run assets --download-tools to install the managed tools explicitly.',
        );
      }
    }
    try {
      for (final file in files) {
        try {
          facts.add(
            await inspectAsset(
              file,
              root: root.path,
              project: project,
              probe: probe,
              textLimit: limit,
            ),
          );
        } on Object catch (error) {
          errors.add('${p.relative(file.path, from: root.path)}: $error');
          Map<String, Object?> fallback;
          try {
            fallback = await inspectAsset(
              file,
              root: root.path,
              project: project,
              textLimit: limit,
            );
          } on Object {
            fallback = {
              'path': p.url.joinAll(p.split(p.relative(file.path, from: root.path))),
              'absolutePath': file.absolute.path,
              'kind': assetKind(file.path),
            };
          }
          facts.add({...fallback, 'metadataError': '$error'});
        }
      }
    } finally {
      tools?.close();
    }
    final report = {
      'schemaVersion': 1,
      'ok': errors.isEmpty,
      'project': project,
      'root': root.path,
      'files': facts,
      'errors': errors,
    };
    if (args.flag('json')) {
      out.writeln(const JsonEncoder.withIndent('  ').convert(report));
    } else {
      for (final file in facts) {
        out.writeln('${file['kind']}: ${file['path']} (${file['sizeBytes'] ?? '?'} bytes)');
      }
      errors.forEach(err.writeln);
    }
    return errors.isEmpty ? 0 : 1;
  }
}
