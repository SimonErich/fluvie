/// Shared author-adapter fragment for immutable, explicitly selected images.
const String aiEvidenceInput = '''
  const evidencePath = String.fromEnvironment('FLUVIE_AI_EVIDENCE_FILE');
  final evidence = evidencePath.isEmpty ? <Object?>[] :
    jsonDecode(await File(evidencePath).readAsString()) as List<Object?>;
  if (evidence.length > 4) throw StateError('Select at most four evidence images.');
  final evidenceImages = <AiImage>[];
  for (final value in evidence) {
    final image = value as Map<String, Object?>;
    final file = File(image['filePath'] as String);
    if (await file.length() > 4 * 1024 * 1024) throw StateError('Evidence image exceeds 4 MiB.');
    evidenceImages.add(AiImage(bytes: await file.readAsBytes(),
      mediaType: image['mediaType'] as String, description: image['caption'] as String));
  }
''';
