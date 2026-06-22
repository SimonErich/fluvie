import 'package:meta/meta.dart';

/// One documentation page: its repo-relative path, title, and full markdown.
@immutable
final class DocPage {
  /// Creates a page.
  const DocPage({required this.path, required this.title, required this.body});

  /// The posix-relative path under the docs directory (e.g. `guides/ai-and-mcp.md`).
  final String path;

  /// The page title (its first H1, or the file name when there is none).
  final String title;

  /// The full markdown source.
  final String body;
}
