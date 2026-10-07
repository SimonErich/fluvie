import 'package:fluvie_cli/src/templates/ai_evidence_template.dart';
import 'package:fluvie_cli/src/templates/ai_prompt_template.dart';
import 'package:fluvie_cli/src/templates/ai_trace_template.dart';

/// Package-owned author adapter for exact Dart replacements. It shares the AI
/// clients and provider configuration with spec authoring without importing
/// Flutter into the CLI process.
String dartEditInputSource() =>
    '''
import 'dart:convert';
import 'dart:io';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

Future<Video> build() async {
  const sourcePath = String.fromEnvironment('FLUVIE_AI_DART_SOURCE');
  const output = String.fromEnvironment('FLUVIE_RENDER_SPEC_OUT');
$aiPromptInputSource
  const provider = String.fromEnvironment('FLUVIE_AI_PROVIDER');
  const contextPath = String.fromEnvironment('FLUVIE_AI_CONTEXT_FILE');
  final source = await File(sourcePath).readAsString();
  const api = String.fromEnvironment('FLUVIE_AI_DART_API_B64');
  final apiContext = api.isEmpty ? '' : utf8.decode(base64Decode(api));
  final assetContext = contextPath.isEmpty ? '' : await File(contextPath).readAsString();
  final context = [apiContext, assetContext].where((text) => text.isNotEmpty).join('\\n\\n');
  final baseClient = aiClientFromEnv({
    ...Platform.environment,
    if (provider.isNotEmpty) 'FLUVIE_AI_PROVIDER': provider,
  });
$aiTraceClientSource
$aiEvidenceInput
  final reply = await DartEditService(client: client).edit(prompt,
    source: source, context: context, evidenceImages: evidenceImages);
  final file = File(output);
  await file.parent.create(recursive: true);
  await file.writeAsString(reply);
  return VideoSpec.fromJson({
    'fluvieSpec': 1,
    'scenes': [{'duration': '1s', 'children': <Object?>[]}],
  }).build();
}
''';
