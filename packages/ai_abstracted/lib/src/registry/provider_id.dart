/// The providers this package can talk to.
enum ProviderId {
  /// Google Gemini (text and image; "Nano Banana" image model).
  gemini,

  /// Google Veo (video), accessed through the Gemini API.
  veo,

  /// OpenAI (image via gpt-image-1).
  openai,

  /// Black Forest Labs FLUX (image).
  flux,

  /// ElevenLabs (speech and sound effects).
  elevenLabs,

  /// Suno (music).
  suno,

  /// Anthropic Claude (text).
  claude,

  /// Mistral (text).
  mistral,

  /// Ollama (local text; keyless).
  ollama;

  /// A stable lower-case wire name for this provider.
  String get id {
    switch (this) {
      case ProviderId.gemini:
        return 'gemini';
      case ProviderId.veo:
        return 'veo';
      case ProviderId.openai:
        return 'openai';
      case ProviderId.flux:
        return 'flux';
      case ProviderId.elevenLabs:
        return 'elevenlabs';
      case ProviderId.suno:
        return 'suno';
      case ProviderId.claude:
        return 'claude';
      case ProviderId.mistral:
        return 'mistral';
      case ProviderId.ollama:
        return 'ollama';
    }
  }
}
