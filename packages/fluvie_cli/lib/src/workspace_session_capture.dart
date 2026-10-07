part of 'workspace_session.dart';

extension _WorkspaceCapture on WorkspaceSession {
  Future<Map<String, Object?>> _executeCapture(Map<String, Object?> options, Directory job) async {
    final operation = options['operation']! as String;
    final format = options['format'] as String?;
    final output = p.join(job.path, switch (operation) {
      'frame' => 'frame.png',
      'review' => 'review.json',
      'inspect' => 'inspection.json',
      _ => switch (format) {
        'gif' => 'video.gif',
        'transparent' => 'video.webm',
        'imageSequence' => 'frames',
        _ => 'video.mp4',
      },
    });
    Map<String, Object?>? captured;
    try {
      await runRenderPipeline(
        runner: runner,
        createSandbox: () => Directory.systemTemp.createTemp('fluvie_workspace_capture_'),
        options: (
          ffmpegBinary: toolchain.ffmpegPath,
          projectDir: target.projectDir,
          noCache: true,
          noDownload: true,
          enableImpeller: impeller,
          verbose: false,
          keepTemp: false,
        ),
        key: p.relative(target.path, from: target.projectDir),
        outPath: output,
        frames: options['frameCount'] as int?,
        flags: (
          aspect: validateEnumFlag(
            options['aspect'] as String?,
            flag: 'aspect',
            allowed: aspectNames,
          ),
          quality: validateEnumFlag(
            options['quality'] as String?,
            flag: 'quality',
            allowed: qualityNames,
          ),
          format: validateEnumFlag(format, flag: 'format', allowed: formatNames),
          poster: null,
        ),
        extraDefines: {'FLUVIE_OPERATION': operation},
        out: StringBuffer(),
        err: err,
        resolveToolchain:
            (
              runner, {
              binary,
              probeBinary,
              mode = 'managed',
              allowDownload = true,
              log = _silentWorkspace,
            }) async => toolchain,
        capture: (sandbox, fingerprint) async {
          if (_capture == null && _worker == null) {
            _worker = await NativeRenderWorker.start(
              target: target,
              toolchain: toolchain,
              err: err,
              runner: runner,
              startupTimeout: workerStartupTimeout,
              requestTimeout: workerRequestTimeout,
              impeller: impeller,
            );
          }
          captured = await (_capture ?? _worker!.client.execute)({
            'outputDir': sandbox.path,
            'projectDir': target.projectDir,
            'compositionKey': target.path,
            'compositionFingerprint': fingerprint,
            for (final entry in options.entries)
              if (!{'sourceRevision', 'strictQuality', 'allowQuality'}.contains(entry.key))
                entry.key: entry.value,
            if (operation == 'review') 'reviewOutputDir': job.path,
          });
        },
      );
    } on Object {
      if (_worker?.client.retired ?? false) {
        await _worker?.close();
        _worker = null;
      }
      rethrow;
    }
    final result = <String, Object?>{
      'operation': operation,
      'filePath': output,
      'captureMilliseconds': captured?['elapsedMilliseconds'],
      if (operation == 'frame') 'frame': options['frameIndex'] ?? 0,
    };
    if (operation == 'review' || operation == 'inspect') {
      result['report'] = jsonDecode(await File(output).readAsString());
    }
    if (operation == 'render') {
      final receipt = jsonDecode(
        await File(
          p.join(job.path, '${p.basenameWithoutExtension(output)}.render.json'),
        ).readAsString(),
      );
      result['receipt'] = receipt;
      result['audioQuality'] = await reviewArtifactAudio(receipt as Map<String, Object?>, runner);
    }
    final report = result['report'] as Map<String, Object?>?;
    final audio = result['audioQuality'] as Map<String, Object?>?;
    final quality = report?['quality'] as Map<String, Object?>? ?? const {};
    if (operation == 'review' || operation == 'render') {
      result['quality'] = evaluateReviewQuality(
        {
          ...quality,
          'audio': ?audio,
          'findings': [...?(quality['findings'] as List?), ...?(audio?['findings'] as List?)],
        },
        allowed: ((options['allowQuality'] as List?) ?? const []).cast<String>().toSet(),
        strict: options['strictQuality'] == true,
      );
      result['ok'] = (result['quality']! as Map)['ok'];
    }
    return result;
  }
}

void _silentWorkspace(String _) {}
