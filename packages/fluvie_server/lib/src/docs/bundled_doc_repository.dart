import 'package:fluvie_cli/docs.dart';
import 'package:fluvie_server/src/docs/doc_page.dart';
import 'package:fluvie_server/src/docs/doc_repository.dart';

/// Versioned canonical docs shipped with the CLI and server binary.
final class BundledDocRepository implements DocRepository {
  /// Creates the offline documentation repository.
  const BundledDocRepository();

  @override
  List<DocPage> load() => [
    for (final page in bundledDocumentation)
      DocPage(path: page.path, title: page.title, body: page.body),
  ];
}
