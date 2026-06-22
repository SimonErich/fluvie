import 'dart:convert';

import 'package:fluvie_server/src/api/client/api_client_exception.dart';
import 'package:fluvie_server/src/api/client/api_render_client.dart';
import 'package:fluvie_server/src/api/client/api_render_request.dart';
import 'package:fluvie_server/src/api/client/api_validation_result.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  final base = Uri.parse('https://render.test/');

  group('ApiRenderRequest.code', () {
    test('builds a {code: ...} body, merging options', () {
      final json = ApiRenderRequest.code(
        'Video build() => Video(scenes: []);',
        format: 'gif',
      ).toJson();

      expect(json['code'], 'Video build() => Video(scenes: []);');
      expect((json['options']! as Map)['format'], 'gif');
    });
  });

  group('ApiValidationResult.fromJson', () {
    test('parses ok with no diagnostics', () {
      final result = ApiValidationResult.fromJson(const {'ok': true, 'diagnostics': <Object?>[]});

      expect(result.ok, isTrue);
      expect(result.diagnostics, isEmpty);
    });

    test('parses located diagnostics and severities', () {
      final result = ApiValidationResult.fromJson(const {
        'ok': false,
        'diagnostics': [
          {
            'severity': 'error',
            'message': 'Undefined.',
            'line': 3,
            'column': 5,
            'length': 4,
            'code': 'undefined_identifier',
          },
          {'severity': 'warning', 'message': 'Unused.', 'line': 1, 'column': 1},
        ],
      });

      expect(result.ok, isFalse);
      expect(result.diagnostics, hasLength(2));
      expect(result.diagnostics.first.severity, ApiDiagnosticSeverity.error);
      expect(result.diagnostics.first.line, 3);
      expect(result.diagnostics.first.length, 4);
      expect(result.diagnostics.first.code, 'undefined_identifier');
      expect(result.diagnostics[1].severity, ApiDiagnosticSeverity.warning);
      expect(result.diagnostics[1].length, isNull);
    });
  });

  group('ApiRenderClient.validate', () {
    ApiRenderClient client(MockClient mock, {String? token}) =>
        ApiRenderClient(baseUrl: base, apiToken: token, httpClient: mock);

    test('posts the code to /v1/validate and parses the result', () async {
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'ok': false,
            'diagnostics': [
              {'severity': 'error', 'message': 'x', 'line': 2, 'column': 1},
            ],
          }),
          200,
        );
      });

      final result = await client(mock, token: 'secret').validate('bad');

      expect(seen.method, 'POST');
      expect(seen.url, base.resolve('v1/validate'));
      expect(seen.headers['authorization'], 'Bearer secret');
      expect(jsonDecode(seen.body), {'code': 'bad'});
      expect(result.ok, isFalse);
      expect(result.diagnostics.single.line, 2);
    });

    test('throws ApiClientException on a non-200', () async {
      final mock = MockClient((_) async => http.Response('{}', 500));

      expect(() => client(mock).validate('x'), throwsA(isA<ApiClientException>()));
    });
  });
}
