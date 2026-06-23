import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/playground/stub_ai_author_backend.dart';

/// The AI Assistant's backend: turn a natural-language prompt into a Fluvie
/// `Video build()` snippet, or edit existing code with a new instruction.
///
/// Abstract so the UI is testable with a fake and the generator is swappable.
/// The demo currently binds a local [StubAiAuthorBackend] (see
/// [createAiAuthorBackend]); a future transport will call `fluvie_ai` through
/// `fluvie_server`, because the browser cannot run the model or hold an API key.
// ignore: one_member_abstracts
abstract interface class AiAuthorBackend {
  /// Generates a `Video build()` from [prompt].
  ///
  /// When [currentCode] is given the prompt is an edit instruction applied to
  /// that code; otherwise it is a fresh request. Returns the generated Dart.
  Future<AiAuthorResult> author(String prompt, {String? currentCode});
}

/// The outcome of an [AiAuthorBackend.author] call: the generated Dart source.
final class AiAuthorResult {
  /// Creates a result wrapping the generated [code].
  const AiAuthorResult({required this.code});

  /// The generated Fluvie `Video build()` Dart source.
  final String code;
}

/// A failure from an [AiAuthorBackend] whose [message] is ready to show the user.
///
/// A backend throws this for an expected, explainable problem (the free quota is
/// spent, AI is off on this server, the prompt could not be turned into a video)
/// so the UI shows the message as-is instead of a raw error dump.
final class AiAuthorException implements Exception {
  /// Creates an exception carrying a user-facing [message].
  const AiAuthorException(this.message);

  /// The user-facing description of what went wrong.
  final String message;

  @override
  String toString() => message;
}

/// The AI author backend for this build; overridden with a fake in tests.
final aiAuthorBackendProvider = Provider<AiAuthorBackend>((_) => createAiAuthorBackend());
