part of 'benchmark_command.dart';

extension _BenchmarkCase on BenchmarkCommand {
  Future<Map<String, Object?>> _case(
    Map<String, Object?> task,
    Directory output, {
    required ArgResults args,
    required String project,
    required Map<String, String> sources,
    required String provider,
    required String model,
    required StringSink err,
  }) async {
    final id = task['id']! as String;
    final action = task['action']! as String;
    final prompt = task['prompt']! as String;
    final env = {...environment, 'FLUVIE_AI_MODEL': model};
    final flags = <String>[
      '--project',
      project,
      for (final key in ['ffmpeg', 'ffprobe', 'toolchain'])
        if (args.option(key) case final String value) ...['--$key', value],
      if (args.flag('no-download')) '--no-download',
    ];
    final logs = StringBuffer();
    String? before;
    String source;
    var code = 0;
    if (action == 'generate') {
      source = p.join(project, 'lib', 'benchmark_${id}_${uniqueStageId()}.dart');
      final contextFiles = task['contextFiles'] as List? ?? const [];
      code = await GenerateCommand(environment: env).execute(
        GenerateCommand.buildParser().parse([
          prompt,
          ...flags,
          '--provider',
          provider,
          '--ai-trace',
          p.join(output.path, 'ai-trace.json'),
          '--no-render',
          '--dart-out',
          source,
          '--spec-out',
          p.join(output.path, 'authored.fluvie.json'),
          for (final file in contextFiles.cast<String>()) ...['--context-file', file],
        ]),
        out: logs,
        err: logs,
      );
    } else {
      final base =
          sources[task['base']] ??
          (task['source'] is String ? p.join(project, task['source']! as String) : null);
      if (base == null || !File(base).existsSync() || !p.isWithin(project, p.absolute(base))) {
        throw const CliFailure('Benchmark base source is missing or outside its fixture project.');
      }
      before = await File(base).readAsString();
      await File(p.join(output.path, 'before.dart')).writeAsString(before);
      source = p.join(p.dirname(base), 'benchmark_${id}_${uniqueStageId()}.dart');
      await File(base).copy(source);
      if (action == 'edit') {
        code = await EditCommand(environment: env).execute(
          EditCommand.buildParser().parse([
            source,
            prompt,
            ...flags,
            '--provider',
            provider,
            '--ai-trace',
            p.join(output.path, 'ai-trace.json'),
            '--no-render',
          ]),
          out: logs,
          err: logs,
        );
      }
    }
    var safeLogs = logs.toString();
    for (final key in environment.keys.where(
      (key) => key.contains('API_KEY') || key.endsWith('TOKEN'),
    )) {
      final value = environment[key]!;
      if (value.isNotEmpty) safeLogs = safeLogs.replaceAll(value, '[REDACTED]');
    }
    await File(p.join(output.path, 'commands.log')).writeAsString(safeLogs);
    if (File(source).existsSync()) {
      await File(source).copy(p.join(output.path, 'candidate.dart'));
    }
    if (code != 0 || !File(source).existsSync()) {
      throw CliFailure('Authoring failed (exit $code). See commands.log.');
    }
    sources[id] = source;
    final reviewOutput = StringBuffer();
    final reviewFlags = flags;
    final reviewCode = await ReviewCommand().execute(
      ReviewCommand.buildParser().parse([
        source,
        ...reviewFlags,
        '--determinism',
        '--render',
        '--strict-decode',
        '--json',
        '--out-dir',
        p.join(output.path, 'review'),
        if (args.option('frames') case final String count) ...['--frames', count],
      ]),
      out: reviewOutput,
      err: err,
    );
    final review = jsonDecode(reviewOutput.toString().trim()) as Map<String, Object?>;
    final artifact = review['artifact'] as Map<String, Object?>?;
    final verification = artifact?['verification'] as Map<String, Object?>?;
    final formats = <Map<String, Object?>>[];
    if (action == 'formats') {
      for (final aspect in ['square', 'reels', 'landscape']) {
        final formatOut = StringBuffer();
        final formatCode = await ReviewCommand().execute(
          ReviewCommand.buildParser().parse([
            source,
            ...reviewFlags,
            '--render',
            '--json',
            '--aspect',
            aspect,
            '--out-dir',
            p.join(output.path, aspect),
            if (args.option('frames') case final String count) ...['--frames', count],
          ]),
          out: formatOut,
          err: err,
        );
        formats.add({
          'aspect': aspect,
          'ok': formatCode == 0,
          'report': jsonDecode(formatOut.toString().trim()),
        });
      }
    }
    return {
      'ok': reviewCode == 0 && formats.every((format) => format['ok'] == true),
      'beforeSource': before,
      'afterSource': await File(source).readAsString(),
      'sourcePath': source,
      'renderVerified': verification?['ok'] == true,
      'review': review,
      if (formats.isNotEmpty) 'formats': formats,
    };
  }
}
