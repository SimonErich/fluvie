import 'dart:io';

import 'package:fluvie_cli/src/cli_failure.dart';
import 'package:fluvie_cli/src/process_runner.dart';
import 'package:fluvie_cli/src/render_manifest.dart';

/// Runs the encode step: read `manifest.json` from [sandbox], validate its
/// sandbox confinement, spawn ffmpeg with **exactly** the manifest's argument
/// array (cwd = sandbox), then move the produced output to [outPath].
///
/// Single-file modes (mp4/gif/transparent/poster) move one output file to
/// [outPath]. The image-sequence export (its `outputFileName` is an `image2`
/// `frame_%06d.png` pattern, not a real file) writes N stills; for it [outPath]
/// is treated as a target **directory** that receives every produced frame.
///
/// Returns the final output file or, for the image sequence, the destination
/// directory as a [File] handle. Every failure is a [CliFailure].
Future<File> runEncode({
  required ProcessRunner runner,
  required Directory sandbox,
  required String outPath,
  String? ffmpegBinary,
}) async {
  final manifest = RenderManifest.read(sandbox)..validateSandboxConfinement(sandbox);
  final result = await runner.run(
    ffmpegBinary ?? 'ffmpeg',
    manifest.ffmpegArgs,
    workingDirectory: sandbox.path,
  );
  if (result.exitCode != 0) {
    throw CliFailure(
      'ffmpeg failed with exit code ${result.exitCode}.\n${_tail(result.stderr)}',
    );
  }
  final output = manifest.isImageSequence
      ? await _collectImageSequence(manifest, sandbox, outPath)
      : await _moveSingleOutput(manifest, sandbox, outPath);
  await _runPoster(runner, manifest, sandbox, outPath, ffmpegBinary);
  return output;
}

/// Moves the one concrete output a single-file mode wrote (`out.mp4`,
/// `out.gif`, `out.webm`) to [outPath], failing if ffmpeg exited 0 without it.
Future<File> _moveSingleOutput(
  RenderManifest manifest,
  Directory sandbox,
  String outPath,
) async {
  final produced = File('${sandbox.path}/${manifest.outputFileName}');
  if (!produced.existsSync()) {
    throw CliFailure(
      'ffmpeg exited 0 but produced no ${manifest.outputFileName} in '
      '${sandbox.path}.',
    );
  }
  return moveIntoPlace(produced, outPath);
}

/// Moves every still the `image2` muxer wrote — those whose names match the
/// pattern's literal prefix/suffix (e.g. `frame_*.png`) — into [outPath],
/// treated as a target directory created on demand.
///
/// Fails with a [CliFailure] naming the pattern when ffmpeg exited 0 yet wrote
/// no matching stills. [_matchesPattern] is the security boundary: it accepts a
/// name only when it is `<prefix><digits><suffix>` over the bare base name, so a
/// matched still is always a separator and `..`-free name that cannot escape the
/// destination directory when appended to the move target.
Future<File> _collectImageSequence(
  RenderManifest manifest,
  Directory sandbox,
  String outPath,
) async {
  final bounds = manifest.imageSequenceBounds;
  final stills =
      sandbox
          .listSync()
          .whereType<File>()
          .where((file) => _matchesPattern(_baseName(file.path), bounds))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (stills.isEmpty) {
    throw CliFailure(
      'ffmpeg exited 0 but produced no ${manifest.outputFileName} stills in '
      '${sandbox.path}.',
    );
  }
  final destination = Directory(outPath);
  await destination.create(recursive: true);
  for (final still in stills) {
    await moveIntoPlace(still, '${destination.path}/${_baseName(still.path)}');
  }
  return File(destination.path);
}

/// Whether [name] is a still produced by the sequence pattern: it starts with
/// the literal prefix, ends with the literal suffix, and the index between them
/// is a non-empty run of digits (what `image2` substitutes for `%0Nd`).
///
/// A digit-only middle segment cannot hold a `/`, `\` or `..`, so a name this
/// accepts is guaranteed safe to append to the destination directory.
bool _matchesPattern(String name, ({String prefix, String suffix}) bounds) {
  if (!name.startsWith(bounds.prefix) || !name.endsWith(bounds.suffix)) return false;
  final index = name.substring(
    bounds.prefix.length,
    name.length - bounds.suffix.length,
  );
  return index.isNotEmpty && index.codeUnits.every(_isDigit);
}

/// Whether [codeUnit] is an ASCII digit `0`-`9` (so the index segment can never
/// smuggle a separator or a sign past [_matchesPattern]).
bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

/// The trailing path segment of [path] (its bare file name).
String _baseName(String path) => path.split(Platform.pathSeparator).last;

/// Runs the SECOND poster invocation when the manifest carries one, moving the
/// extracted still to a `.poster.png` sibling of [outPath]. A no-poster
/// manifest is a no-op.
Future<void> _runPoster(
  ProcessRunner runner,
  RenderManifest manifest,
  Directory sandbox,
  String outPath,
  String? ffmpegBinary,
) async {
  final posterArgs = manifest.posterArgs;
  final posterFileName = manifest.posterFileName;
  if (posterArgs == null || posterFileName == null) return;
  final result = await runner.run(
    ffmpegBinary ?? 'ffmpeg',
    posterArgs,
    workingDirectory: sandbox.path,
  );
  if (result.exitCode != 0) {
    throw CliFailure(
      'The poster extraction (ffmpeg) failed with exit code ${result.exitCode}.\n'
      '${_tail(result.stderr)}',
    );
  }
  final poster = File('${sandbox.path}/$posterFileName');
  if (!poster.existsSync()) {
    throw CliFailure('ffmpeg exited 0 but produced no poster $posterFileName in ${sandbox.path}.');
  }
  await moveIntoPlace(poster, _posterPathFor(outPath));
}

/// The `.poster.png` path beside [outPath] (e.g. `demo.mp4` -> `demo.poster.png`).
String _posterPathFor(String outPath) => outPath.replaceFirst(RegExp(r'\.[^.]+$'), '.poster.png');

/// Moves [source] to [targetPath], creating parent directories.
///
/// Copies then deletes the source instead of renaming: a rename fails across
/// filesystems (the sandbox lives under the system temp directory, the
/// target can be anywhere), and the copy is equally atomic for our purposes
/// because the manifest protocol already signalled completion.
Future<File> moveIntoPlace(File source, String targetPath) async {
  final target = File(targetPath);
  await target.parent.create(recursive: true);
  final moved = await source.copy(target.path);
  await source.delete();
  return moved;
}

/// Keeps the last 4 KiB of [output] for diagnostics.
String _tail(String output) =>
    output.length <= 4096 ? output : output.substring(output.length - 4096);
