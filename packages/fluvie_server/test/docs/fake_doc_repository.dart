import 'package:fluvie_server/src/docs/doc_page.dart';
import 'package:fluvie_server/src/docs/doc_repository.dart';

/// A [DocRepository] over a fixed list of pages, for tests without disk.
final class FakeDocRepository implements DocRepository {
  FakeDocRepository(this.pages);

  /// A small, distinctive corpus that makes ranking assertions clear.
  factory FakeDocRepository.sample() => FakeDocRepository(const [
    DocPage(
      path: 'guides/ai-and-mcp.md',
      title: 'AI and MCP',
      body:
          '# AI and MCP\nUse the MCP server to author Fluvie videos from a prompt. '
          'The model emits a VideoSpec which the server renders.',
    ),
    DocPage(
      path: 'guides/audio-and-captions.md',
      title: 'Audio and captions',
      body:
          '# Audio and captions\nAdd an audio track and burned-in captions to a video. '
          'Captions are timed to the beat.',
    ),
    DocPage(
      path: 'getting-started/installation.md',
      title: 'Installation',
      body:
          '# Installation\nInstall Fluvie and the CLI with dart pub. '
          'Then provision ffmpeg before your first render.',
    ),
  ]);

  final List<DocPage> pages;

  @override
  List<DocPage> load() => pages;
}
