import 'dart:io';

import 'package:fluvie_server/src/docs/doc_page.dart';

/// Loads the documentation pages the helper searches.
///
/// One contract over the bundled markdown directory (the production source) and
/// an in-memory fake for tests.
// ignore: one_member_abstracts — the seam is the type; a fake backs it in tests.
abstract interface class DocRepository {
  /// Loads every page, once, at startup.
  List<DocPage> load();
}

/// A [DocRepository] backed by a directory of markdown files (`FLUVIE_DOCS_DIR`).
///
/// Reads every `*.md` under [root] recursively, sorted by path so the corpus —
/// and therefore search ranking — is deterministic. A missing directory yields
/// an empty corpus rather than throwing, so a docs-disabled server still boots.
final class FileDocRepository implements DocRepository {
  /// Creates a repository over [root].
  const FileDocRepository(this.root);

  /// The directory markdown is read from.
  final Directory root;

  @override
  List<DocPage> load() {
    if (!root.existsSync()) return const [];
    final pages = <DocPage>[];
    // Do not follow symlinks: it avoids loops and keeps the corpus inside the
    // docs root, so a link can't expose a file from elsewhere on disk.
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.md')) continue;
      final path = _relative(entity.path);
      final body = entity.readAsStringSync();
      pages.add(DocPage(path: path, title: _title(path, body), body: body));
    }
    pages.sort((a, b) => a.path.compareTo(b.path));
    return pages;
  }

  String _relative(String absolute) {
    var rel = absolute;
    if (rel.startsWith(root.path)) rel = rel.substring(root.path.length);
    rel = rel.replaceAll(r'\', '/');
    return rel.startsWith('/') ? rel.substring(1) : rel;
  }

  static String _title(String path, String body) {
    for (final line in body.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ')) return trimmed.substring(2).trim();
    }
    final name = path.split('/').last;
    return name.endsWith('.md') ? name.substring(0, name.length - 3) : name;
  }
}
