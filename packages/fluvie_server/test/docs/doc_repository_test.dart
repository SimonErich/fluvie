import 'dart:io';

import 'package:fluvie_server/src/docs/doc_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('fluvie_server_docs_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  File write(String relative, String content) {
    final file = File('${root.path}/$relative')..createSync(recursive: true);
    return file..writeAsStringSync(content);
  }

  test('loads markdown files recursively, sorted by path', () {
    write('guides/intro.md', '# Intro\nhi');
    write('getting-started/install.md', '# Install\nstuff');
    write('notes.txt', 'ignored, not markdown');

    final pages = FileDocRepository(root).load();

    expect(pages.map((p) => p.path), ['getting-started/install.md', 'guides/intro.md']);
  });

  test('uses the first H1 as the title', () {
    write('a.md', 'intro line\n# The Real Title\nmore');

    final pages = FileDocRepository(root).load();

    expect(pages.single.title, 'The Real Title');
  });

  test('falls back to the file name when there is no H1', () {
    write('guides/no-heading.md', 'just body text, no heading');

    final pages = FileDocRepository(root).load();

    expect(pages.single.title, 'no-heading');
  });

  test('keeps the full markdown body', () {
    write('a.md', '# Title\nline one\nline two');

    final pages = FileDocRepository(root).load();

    expect(pages.single.body, '# Title\nline one\nline two');
  });

  test('returns an empty corpus when the directory is missing', () {
    final missing = Directory('${root.path}/does-not-exist');

    expect(FileDocRepository(missing).load(), isEmpty);
  });

  test('does not follow a symlink that points outside the docs root', () {
    final outside = Directory.systemTemp.createTempSync('fluvie_server_outside_');
    addTearDown(() => outside.deleteSync(recursive: true));
    File('${outside.path}/secret.md').writeAsStringSync('# Secret\noutside the docs root');
    write('real.md', '# Real\ninside');
    Link('${root.path}/leaked.md').createSync('${outside.path}/secret.md');

    final paths = FileDocRepository(root).load().map((p) => p.path);

    expect(paths, ['real.md']);
  });
}
