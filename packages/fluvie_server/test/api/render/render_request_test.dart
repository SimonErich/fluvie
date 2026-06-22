import 'package:fluvie_server/src/api/jobs/render_job.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:test/test.dart';

void main() {
  Map<String, Object?> spec() => {
    'scenes': [
      {'duration': '2s'},
    ],
  };

  group('RenderRequest.fromJson dispatch', () {
    test('parses a key request', () {
      final request = RenderRequest.fromJson({'key': 'demo'});
      expect(request, isA<KeyRenderRequest>());
      expect((request as KeyRenderRequest).key, 'demo');
      expect(request.kind, RenderJobKind.key);
    });

    test('parses a spec request', () {
      final request = RenderRequest.fromJson({'spec': spec()});
      expect(request, isA<SpecRenderRequest>());
      expect(request.kind, RenderJobKind.spec);
    });

    test('parses a prompt request with a provider', () {
      final request = RenderRequest.fromJson({'prompt': 'a promo', 'provider': 'gemini'});
      expect(request, isA<PromptRenderRequest>());
      expect((request as PromptRenderRequest).prompt, 'a promo');
      expect(request.provider, 'gemini');
    });

    test('parses an edit request', () {
      final request = RenderRequest.fromJson({
        'edit': {'base': spec(), 'change': 'make it blue'},
      });
      expect(request, isA<EditRenderRequest>());
      expect((request as EditRenderRequest).change, 'make it blue');
      expect(request.kind, RenderJobKind.edit);
    });

    test('parses a code request', () {
      final request = RenderRequest.fromJson({'code': 'Video build() => Video(scenes: []);'});
      expect(request, isA<CodeRenderRequest>());
      expect((request as CodeRenderRequest).code, 'Video build() => Video(scenes: []);');
      expect(request.kind, RenderJobKind.code);
    });
  });

  group('RenderRequest.fromJson validation', () {
    void rejects(Map<String, Object?> json, String fragment) {
      expect(
        () => RenderRequest.fromJson(json),
        throwsA(
          isA<RenderRequestException>().having((e) => e.message, 'message', contains(fragment)),
        ),
      );
    }

    test('requires exactly one input', () {
      rejects({}, 'exactly one');
      rejects({'key': 'demo', 'spec': spec()}, 'exactly one');
    });

    test('rejects a non-snake_case key', () => rejects({'key': 'Demo Key'}, 'snake_case'));
    test('rejects an empty prompt', () => rejects({'prompt': '  '}, 'non-empty'));
    test('rejects a spec without scenes', () => rejects({'spec': <String, Object?>{}}, 'scenes'));
    test('rejects a spec that is not an object', () => rejects({'spec': 5}, 'VideoSpec object'));
    test('rejects an edit missing change', () {
      rejects({
        'edit': {'base': spec()},
      }, 'change');
    });
    test('rejects an edit whose base lacks scenes', () {
      rejects({
        'edit': {'base': <String, Object?>{}, 'change': 'x'},
      }, 'scenes');
    });
    test('rejects a non-object edit', () => rejects({'edit': 'nope'}, 'object'));
    test('rejects a non-string provider', () => rejects({'prompt': 'p', 'provider': 5}, 'string'));
    test('rejects an empty code snippet', () => rejects({'code': '   '}, 'non-empty'));
    test('rejects code combined with another input', () {
      rejects({'code': 'x', 'key': 'demo'}, 'exactly one');
    });
  });

  group('RenderRequest.fromJson options', () {
    test('parses valid export options', () {
      final request = RenderRequest.fromJson({
        'key': 'demo',
        'options': {'format': 'gif', 'aspect': 'square', 'quality': 'max', 'poster': '1.5s'},
      });
      expect(request.options.format, 'gif');
      expect(request.options.aspect, 'square');
      expect(request.options.quality, 'max');
      expect(request.options.poster, '1.5s');
    });

    test('defaults to no options', () {
      final request = RenderRequest.fromJson({'key': 'demo'});
      expect(request.options.format, isNull);
      expect(request.options.aspect, isNull);
    });

    test('rejects a bad enum, empty poster, non-object options, and imageSequence', () {
      void rejects(Object? options, String fragment) {
        expect(
          () => RenderRequest.fromJson({'key': 'demo', 'options': options}),
          throwsA(isA<RenderRequestException>().having((e) => e.message, 'm', contains(fragment))),
        );
      }

      rejects({'format': 'avi'}, 'format');
      rejects({'poster': ''}, 'poster');
      rejects('nope', 'object');
      rejects({'format': 'imageSequence'}, 'imageSequence');
    });
  });
}
