/// Optional authoring evidence sink in the managed Flutter adapter. The trace
/// contains model messages and replies, never transport headers or credentials.
const aiTraceClientSource = r'''
  const tracePath = String.fromEnvironment('FLUVIE_AI_TRACE_OUT');
  final records = <Map<String, Object?>>[];
  final client = tracePath.isEmpty ? baseClient : RecordingAiClient(
    client: baseClient,
    record: (record) async {
      records.add({
        'messages': [for (final message in record.request.messages)
          {'role': message.role.name, 'text': message.text, 'hasImage': message.image != null}],
        'reply': record.response?.text,
        'error': record.error?.toString(),
        'elapsedMilliseconds': record.elapsed.inMilliseconds,
      });
      final file = File(tracePath);
      await file.parent.create(recursive: true);
      var encoded = jsonEncode({'schemaVersion': 1, 'attempts': records});
      for (final entry in Platform.environment.entries) {
        if ((entry.key.contains('API_KEY') || entry.key.endsWith('TOKEN')) && entry.value.isNotEmpty) {
          encoded = encoded.replaceAll(entry.value, '[REDACTED]');
        }
      }
      await File('$tracePath.tmp').writeAsString(encoded, flush: true);
      await File('$tracePath.tmp').rename(file.path);
    },
  );
''';
