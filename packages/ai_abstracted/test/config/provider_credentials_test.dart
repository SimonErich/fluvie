import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('ProviderCredentials', () {
    test('requires only an apiKey', () {
      const credentials = ProviderCredentials(apiKey: 'k');
      expect(credentials.apiKey, 'k');
      expect(credentials.baseUrl, isNull);
      expect(credentials.organization, isNull);
      expect(credentials.project, isNull);
      expect(credentials.extra, isEmpty);
    });

    test('carries optional fields', () {
      final credentials = ProviderCredentials(
        apiKey: 'k',
        baseUrl: Uri.parse('https://example.test'),
        organization: 'org',
        project: 'proj',
        extra: const {'region': 'eu'},
      );
      expect(credentials.baseUrl, Uri.parse('https://example.test'));
      expect(credentials.organization, 'org');
      expect(credentials.project, 'proj');
      expect(credentials.extra['region'], 'eu');
    });
  });
}
