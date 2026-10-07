import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:fluvie_cli/src/asset_catalog.dart';
import 'package:fluvie_cli/src/asset_inventory.dart';
import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:fluvie_cli/src/contact_sheet_evidence.dart';
import 'package:fluvie_cli/src/ffmpeg_gate.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_pipeline.dart' show ToolchainResolver;
import 'package:fluvie_media/native.dart';
import 'package:path/path.dart' as p;

/// Writes selected evidence into a content-bound catalog. Contact sheets are
/// local artifacts; no provider receives them until authoring explicitly opts in.
Future<int> executeAssetsCatalog({
  required ArgResults args,
  required Directory root,
  required String project,
  required ProcessRunner runner,
  required StringSink out,
  required StringSink err,
  AssetProbe? probe,
  ToolchainResolver resolveToolchain = ensureFfmpegToolchain,
}) async {
  final path = p.absolute(
    args.option('catalog-out') ?? p.join(project, 'build/fluvie/assets.catalog.json'),
  );
  FfmpegMediaTools? tools;
  var toolchain = const <String, Object?>{};
  try {
    final files = inventoryFiles(root);
    if (args.flag('contact-sheets') || (probe == null && files.any(needsAssetProbe))) {
      final pair = await resolveToolchain(
        runner,
        binary: args.option('ffmpeg'),
        probeBinary: args.option('ffprobe'),
        mode: args.option('toolchain')!,
        allowDownload:
            args.flag('contact-sheets') || args.flag('download-tools') || args.flag('download'),
        log: err.writeln,
      );
      tools = FfmpegMediaTools(ffmpegPath: pair.ffmpegPath, ffprobePath: pair.ffprobePath);
      toolchain = pair.toJson();
      probe ??= tools.probeReport;
    }
    final report = await buildAssetCatalog(
      root: root,
      project: project,
      probe: probe,
      evidenceFile: args.option('evidence'),
      transcripts: args.multiOption('transcript'),
      excludedFiles: {path},
      excludedDirectories: {p.join(p.dirname(path), 'asset_evidence')},
      sheetBuilder: args.flag('contact-sheets')
          ? (file, hash) => cachedContactSheet(
              file,
              sourceHash: hash,
              outputDirectory: p.join(p.dirname(path), 'asset_evidence'),
              toolchain: toolchain,
              capture: tools!.contactSheet,
            )
          : null,
    );
    await atomicWrite(path, const JsonEncoder.withIndent('  ').convert(report));
    final result = {
      'schemaVersion': 1,
      'ok': true,
      'catalogPath': path,
      'assetCount': (report['assets']! as List<Object?>).length,
    };
    if (args.flag('json')) {
      out.writeln(jsonEncode(result));
    } else {
      out.writeln('Catalog $path (${result['assetCount']} assets)');
    }
    return 0;
  } on Object catch (error) {
    if (args.flag('json')) {
      out.writeln(
        jsonEncode({'schemaVersion': 1, 'ok': false, 'catalogPath': path, 'error': '$error'}),
      );
    } else {
      err.writeln('Could not build asset catalog: $error');
    }
    return 1;
  } finally {
    tools?.close();
  }
}
