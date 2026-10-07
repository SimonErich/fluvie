/// Reads ordinary prompts and losslessly encoded multiline prompts. Flutter's
/// test argument parser cannot safely receive line breaks in a dart-define.
const aiPromptInputSource = '''
  const fallbackPrompt = String.fromEnvironment('FLUVIE_AI_PROMPT');
  const encodedPrompt = String.fromEnvironment('FLUVIE_AI_PROMPT_B64');
  final prompt = encodedPrompt.isEmpty ? fallbackPrompt : utf8.decode(base64Decode(encodedPrompt));
''';
