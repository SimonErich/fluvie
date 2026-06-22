import 'package:fluvie_server/src/api/client/api_render_request.dart';
import 'package:test/test.dart';

void main() {
  group('ApiRenderRequest.toJson', () {
    test('a key request with options, visibility, and ttl', () {
      final json = ApiRenderRequest.key(
        'demo',
        format: 'gif',
        aspect: 'square',
        visibility: 'public',
        ttl: '48h',
      ).toJson();
      expect(json['key'], 'demo');
      expect(json['options'], {'format': 'gif', 'aspect': 'square'});
      expect(json['visibility'], 'public');
      expect(json['ttl'], '48h');
    });

    test('a bare key request omits options/visibility/ttl', () {
      final json = ApiRenderRequest.key('demo').toJson();
      expect(json, {'key': 'demo'});
    });

    test('carries quality and poster options', () {
      final json = ApiRenderRequest.key('demo', quality: 'max', poster: '1.5s').toJson();
      expect(json['options'], {'quality': 'max', 'poster': '1.5s'});
    });

    test('an edit request includes the provider when set', () {
      final json = ApiRenderRequest.edit(
        base: const {
          'scenes': [<String, Object?>{}],
        },
        change: 'bluer',
        provider: 'mistral',
      ).toJson();
      expect(json['provider'], 'mistral');
    });

    test('a spec request', () {
      final json = ApiRenderRequest.spec(const {
        'scenes': [<String, Object?>{}],
      }).toJson();
      expect(json['spec'], isA<Map<String, Object?>>());
    });

    test('a prompt request includes the provider when set', () {
      expect(ApiRenderRequest.prompt('a promo', provider: 'gemini').toJson(), {
        'prompt': 'a promo',
        'provider': 'gemini',
      });
      expect(ApiRenderRequest.prompt('a promo').toJson(), {'prompt': 'a promo'});
    });

    test('an edit request nests base and change', () {
      final json = ApiRenderRequest.edit(
        base: const {
          'scenes': [<String, Object?>{}],
        },
        change: 'make it blue',
      ).toJson();
      expect((json['edit']! as Map)['change'], 'make it blue');
    });
  });
}
