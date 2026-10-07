import 'package:fluvie_server/src/docs/bundled_doc_repository.dart';
import 'package:fluvie_server/src/docs/doc_search_service.dart';
import 'package:test/test.dart';

void main() {
  final docs = DocSearchService.fromRepository(const BundledDocRepository());

  test('natural-language authoring queries find the actual canonical guides', () {
    for (final entry in const {
      'local assets': 'getting-started/authoring-with-assets.md',
      'clip audio': 'guides/images-and-video-clips.md',
      'export quality': 'guides/exporting-your-video.md',
      'rendering server': 'guides/rendering-on-a-server.md',
      'requiresAudioAnalysis': 'advanced/frame-builder.md',
      'FLUVIE_AI_ENDPOINT': 'guides/ai-and-mcp.md',
    }.entries) {
      expect(
        docs.search(entry.key).map((hit) => hit.path),
        contains(entry.value),
        reason: entry.key,
      );
    }
  });

  test('API names remain searchable and paths cannot escape the bundle', () {
    expect(docs.search('ClipAudio'), isNotEmpty);
    expect(docs.get('../../pubspec.yaml'), isNull);
  });
}
