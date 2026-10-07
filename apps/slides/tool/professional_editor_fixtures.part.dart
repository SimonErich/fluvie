part of 'professional_editor_journey.dart';

final class _SavedProject implements FluvieFileSaver {
  _SavedProject(this.file);
  final File file;
  @override
  String? get targetPath => null;
  @override
  Future<String?> saveCopy({required String suggestedName, required String contents}) async => null;
  @override
  Future<String?> saveCopyBytes({required String suggestedName, required List<int> bytes}) async =>
      null;
  @override
  Future<String?> saveBundle({
    required String suggestedName,
    required List<int> bytes,
    bool pickNew = false,
  }) async => null;
  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
    bool pickNew = false,
  }) async {
    await file.writeAsString(contents, flush: true);
    return file.path;
  }
}

final class _Imports implements MediaImporter {
  _Imports(this.picks);
  final List<MediaPick> picks;
  @override
  Future<MediaPick?> pickMedia() async => picks.isEmpty ? null : picks.removeAt(0);
}

Future<void> _ffmpeg(List<String> args) async {
  final result = await Process.run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args]);
  if (result.exitCode != 0) throw StateError('Fixture generation failed: ${result.stderr}');
}

Future<List<MediaPick>> _createJourneyFixtures(WidgetTester tester, Directory directory) async {
  await tester.runAsync(() async {
    directory.createSync(recursive: true);
    await _ffmpeg([
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=320x180:r=24:d=4',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=4',
      '-shortest',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '${directory.path}/a.mp4',
    ]);
    await _ffmpeg([
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:s=320x180:r=24:d=4',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=660:sample_rate=48000:duration=4',
      '-shortest',
      '-c:v',
      'libx264',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '${directory.path}/b.mp4',
    ]);
    await _ffmpeg([
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=220:sample_rate=48000:duration=5',
      '${directory.path}/bed.wav',
    ]);
  });
  final picks = (await tester.runAsync(
    () async => [
      for (final name in ['a.mp4', 'b.mp4', 'bed.wav'])
        (await mediaPickFor(name: name, path: '${directory.path}/$name'))!,
    ],
  ))!;
  expect(picks.first.fps, 24);
  expect(picks.last.channels, 1);
  return picks;
}
