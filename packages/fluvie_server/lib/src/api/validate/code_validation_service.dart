import 'package:fluvie_server/src/api/validate/code_validation_result.dart';

/// Validates a snippet of Fluvie Dart code without executing it.
///
/// Implementations run static analysis (and lints) only, so calling [validate]
/// is safe for arbitrary input: it never compiles or runs the code.
// ignore: one_member_abstracts — the seam is the type; a fake backs it in tests.
abstract interface class CodeValidationService {
  /// Analyzes [code] and returns its diagnostics. Never executes the code.
  Future<CodeValidationResult> validate(String code);
}
