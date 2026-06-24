import 'package:fluvie_example/playground/ai_author_backend.dart';

/// A scriptable [AiAuthorBackend] for view-model and widget tests.
///
/// Returns [code] (or throws [error]); records the last prompt and current code
/// it saw, and how many times it was called.
final class FakeAiAuthorBackend implements AiAuthorBackend {
  /// Creates a fake; defaults to a clean success returning [code].
  FakeAiAuthorBackend({this.code = 'GENERATED', this.error});

  /// The Dart source [author] returns (unless [error] is set).
  String code;

  /// When set, [author] throws this instead of returning.
  Object? error;

  /// The prompt passed to the most recent [author] call, or null.
  String? lastPrompt;

  /// The `currentCode` passed to the most recent [author] call, or null.
  String? lastCurrentCode;

  /// How many times [author] was called.
  int calls = 0;

  @override
  Future<AiAuthorResult> author(String prompt, {String? currentCode}) async {
    calls++;
    lastPrompt = prompt;
    lastCurrentCode = currentCode;
    final error = this.error;
    // A test seam: simulate any failure the real generator might raise.
    if (error != null) throw error; // ignore: only_throw_errors
    return AiAuthorResult(code: code);
  }
}
