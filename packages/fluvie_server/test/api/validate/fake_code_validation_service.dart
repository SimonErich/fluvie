import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:fluvie_server/src/api/validate/code_validation_service.dart';

/// A scripted [CodeValidationService] for handler tests: it records every
/// submitted snippet and returns the preset [result] without analyzing anything.
final class FakeCodeValidationService implements CodeValidationService {
  /// Creates the fake, returning [result] for every call (empty = clean).
  FakeCodeValidationService({this.result = const CodeValidationResult(<CodeDiagnostic>[])});

  /// The result handed back from every [validate] call.
  final CodeValidationResult result;

  /// The snippets this fake was asked to validate, in order.
  final List<String> calls = [];

  @override
  Future<CodeValidationResult> validate(String code) async {
    calls.add(code);
    return result;
  }
}
