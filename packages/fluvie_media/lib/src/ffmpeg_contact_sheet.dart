part of 'ffmpeg_media_tools.dart';

/// Bounded visual evidence generation with exact source-time records.
extension FfmpegContactSheets on FfmpegMediaTools {
  /// Writes a contact-sheet PNG, preserving source geometry with letterboxing.
  ///
  /// Default samples cover the source's display timeline. Explicit [timestamps]
  /// select pictures at those source seconds. Repeated pictures are deduplicated.
  /// The returned cells record actual picture times, not invented descriptions.
  Future<MediaContactSheet> contactSheet(
    Uri source, {
    required String outputPath,
    int columns = 3,
    int samples = 6,
    int cellWidth = 320,
    int cellHeight = 180,
    List<double>? timestamps,
    Future<void>? whenCancelled,
  }) async {
    if (samples < 1 ||
        samples > 24 ||
        columns < 1 ||
        columns > 6 ||
        cellWidth < 1 ||
        cellHeight < 1 ||
        cellWidth > 2048 ||
        cellHeight > 2048 ||
        (timestamps != null && (timestamps.isEmpty || timestamps.length > 24))) {
      throw ArgumentError('Use 1–24 samples, 1–6 columns and cells of 1–2048 pixels.');
    }
    if ((timestamps?.length ?? samples) * cellWidth * cellHeight * 4 > defaultFrameBatchBytes) {
      throw ArgumentError(
        'Contact-sheet pictures must fit within '
        '${defaultFrameBatchBytes ~/ (1024 * 1024)} MiB of RGBA.',
      );
    }
    final path = FfmpegMediaTools._path('$source');
    final sandbox = await Directory.systemTemp.createTemp('fluvie_contacts_');
    FfmpegFrameSession? session;
    try {
      final index = await _probeFrameIndex(path, whenCancelled: whenCancelled);
      final timeline = index.timeline;
      final info = MediaSourceInfo.fromReport(
        await probeReport(path, whenCancelled: whenCancelled),
        countedFrames: timeline.frameCount,
      );
      final scale = (cellWidth / info.width).clamp(0, cellHeight / info.height);
      final decodeWidth = (info.width * scale).round().clamp(1, cellWidth);
      final decodeHeight = (info.height * scale).round().clamp(1, cellHeight);
      final requested =
          timestamps ??
          List.generate(
            samples,
            (index) => samples == 1
                ? 0.0
                : timeline.timeForFrame(timeline.frameCount - 1) * index / (samples - 1),
          );
      final selected = <int, double>{};
      for (final time in requested) {
        if (!time.isFinite || time < 0 || time > timeline.durationSeconds) {
          throw ArgumentError.value(time, 'timestamps', 'must lie within the source duration');
        }
        selected.putIfAbsent(timeline.frameAt(time), () => time);
      }
      session = _openIndexedSession(
        path,
        decodeWidth,
        decodeHeight,
        index,
        info.hasAlpha && info.codec == 'vp9' ? 'libvpx-vp9' : null,
        whenCancelled,
      );
      final frames = await session.readFrames(selected.keys);
      final raw = File('${sandbox.path}/pictures.rgba').openWrite();
      try {
        for (final index in selected.keys) {
          raw.add(frames[index]!.rgba);
        }
        await raw.flush();
      } finally {
        await raw.close();
      }
      final count = selected.length;
      final cols = columns.clamp(1, count);
      final rows = (count / cols).ceil();
      final filter =
          'pad=$cellWidth:$cellHeight:(ow-iw)/2:(oh-ih)/2:color=black,'
          'tile=${cols}x$rows:nb_frames=$count:padding=4:margin=4:color=black';
      final result = await run(
        ffmpegPath,
        [
          '-v',
          'error',
          '-nostdin',
          '-f',
          'rawvideo',
          '-pixel_format',
          'rgba',
          '-video_size',
          '${decodeWidth}x$decodeHeight',
          '-framerate',
          '1',
          ...FfmpegMediaTools._localInputProtocols,
          '-i',
          'pictures.rgba',
          '-vf',
          filter,
          '-frames:v',
          '1',
          '-update',
          '1',
          '-y',
          'sheet.png',
        ],
        workingDirectory: sandbox.path,
        whenCancelled: whenCancelled,
      );
      if (result.exitCode != 0) {
        throw FfmpegMediaTools._failure('Creating contact sheet for "$path"', result);
      }
      final output = File(outputPath).absolute;
      await output.parent.create(recursive: true);
      final temporary = await File('${sandbox.path}/sheet.png').copy(
        '${output.path}.${sandbox.uri.pathSegments.where((s) => s.isNotEmpty).last}.tmp',
      );
      try {
        if (Platform.isWindows && output.existsSync()) await output.delete();
        await temporary.rename(output.path);
      } finally {
        if (temporary.existsSync()) await temporary.delete();
      }
      return MediaContactSheet(
        filePath: output.path,
        width: cols * cellWidth + (cols - 1) * 4 + 8,
        height: rows * cellHeight + (rows - 1) * 4 + 8,
        cells: [
          for (final (position, entry) in selected.entries.indexed)
            MediaContactSheetCell(
              frameIndex: entry.key,
              timeSeconds: timeline.timeForFrame(entry.key),
              requestedTimeSeconds: entry.value,
              column: position % cols,
              row: position ~/ cols,
            ),
        ],
      );
    } finally {
      await session?.close();
      await sandbox.delete(recursive: true);
    }
  }
}
