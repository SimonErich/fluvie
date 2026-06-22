import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/json_body.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Request _post(String body) => Request('POST', Uri.parse('http://localhost/x'), body: body);

void main() {
  group('readJsonObject', () {
    test('decodes a JSON object', () async {
      expect(await readJsonObject(_post('{"a":1}')), {'a': 1});
    });

    test('an empty body decodes to an empty map', () async {
      expect(await readJsonObject(_post('')), isEmpty);
    });

    test('rejects invalid JSON with 400', () async {
      await expectLater(
        readJsonObject(_post('{not json')),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    test('rejects a non-object (array) with 400', () async {
      await expectLater(
        readJsonObject(_post('[1,2,3]')),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    test('rejects a body over the cap with 413', () async {
      await expectLater(
        readJsonObject(_post('{"a":"${'x' * 100}"}'), maxBytes: 8),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 413)),
      );
    });
  });
}
