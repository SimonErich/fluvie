import 'dart:convert';

import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/handlers/validate_handler.dart';
import 'package:fluvie_server/src/api/validate/code_validation_result.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_code_validation_service.dart';

void main() {
  Request post(Object? body) => Request(
    'POST',
    Uri.parse('http://localhost/v1/validate'),
    headers: const {'content-type': 'application/json'},
    body: body is String ? body : jsonEncode(body),
  );

  Future<Map<String, Object?>> bodyOf(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, Object?>;

  group('ValidateHandler', () {
    test('returns 200 with ok:true and no diagnostics for clean code', () async {
      final handler = ValidateHandler(validator: FakeCodeValidationService());

      final response = await handler.validate(
        post({'code': 'Video build() => Video(scenes: []);'}),
      );

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      final json = await bodyOf(response);
      expect(json['ok'], isTrue);
      expect(json['diagnostics'], isEmpty);
    });

    test('passes the submitted code through and serializes the diagnostics', () async {
      final fake = FakeCodeValidationService(
        result: const CodeValidationResult([
          CodeDiagnostic(
            severity: CodeDiagnosticSeverity.error,
            message: 'Undefined name Video.',
            line: 3,
            column: 12,
            length: 5,
            code: 'undefined_identifier',
          ),
        ]),
      );
      final handler = ValidateHandler(validator: fake);

      final response = await handler.validate(post({'code': 'Vid(scenes: [])'}));

      expect(response.statusCode, 200);
      final json = await bodyOf(response);
      expect(json['ok'], isFalse);
      final diagnostics = json['diagnostics']! as List;
      expect(diagnostics, hasLength(1));
      final first = diagnostics.single as Map<String, Object?>;
      expect(first['severity'], 'error');
      expect(first['line'], 3);
      expect(first['column'], 12);
      expect(first['length'], 5);
      expect(first['code'], 'undefined_identifier');
      expect(fake.calls.single, 'Vid(scenes: [])');
    });

    test('rejects a body without a code field as 400', () async {
      final handler = ValidateHandler(validator: FakeCodeValidationService());

      await expectLater(
        () => handler.validate(post({'notcode': 1})),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('rejects a blank code string as 400', () async {
      final handler = ValidateHandler(validator: FakeCodeValidationService());

      await expectLater(
        () => handler.validate(post({'code': '   '})),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });
}
