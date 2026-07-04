/// Who authored a message in an AI conversation.
enum AiRole {
  /// Instructions that set the model's behavior.
  system,

  /// Input from the user (the prompt or a refinement request).
  user,

  /// A previous reply from the model (used when feeding errors back).
  assistant,
}
