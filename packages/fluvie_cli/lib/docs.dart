/// Offline, versioned documentation shared by the CLI and MCP server.
library;

import 'dart:convert';

import 'package:fluvie_cli/src/docs/documentation_bundle.g.dart';

/// The Fluvie release the bundled documentation describes.
const String documentationVersion = bundledDocumentationVersion;

/// SHA-256 of the canonical corpus, for detecting documentation drift.
const String documentationDigest = bundledDocumentationDigest;

/// One canonical Markdown page, addressed relative to `documentation/`.
final class DocumentationPage {
  /// Creates a documentation page.
  const DocumentationPage({required this.path, required this.title, required this.body});

  /// The stable source path, for example `guides/audio-and-captions.md`.
  final String path;

  /// The page's first heading.
  final String title;

  /// Complete Markdown, including its compiled examples.
  final String body;
}

/// The full documentation corpus, available without a checkout or network.
final List<DocumentationPage> bundledDocumentation = List.unmodifiable(
  (jsonDecode(utf8.decode(base64Decode(bundledDocumentationBase64))) as List<Object?>).map((raw) {
    final page = raw! as Map<String, Object?>;
    return DocumentationPage(
      path: page['path']! as String,
      title: page['title']! as String,
      body: page['body']! as String,
    );
  }),
);

const _authoringInstructions =
    'Use the installed APIs and the real local assets. '
    'Read further pages with fluvie docs or the MCP documentation tools.';

/// A focused, reproducible starting context for a coding assistant.
String authoringContext() => [
  '# Fluvie $documentationVersion authoring context',
  'Corpus SHA-256: $documentationDigest. $_authoringInstructions',
  for (final path in const [
    'getting-started/authoring-with-assets.md',
    'getting-started/core-concepts.md',
    'reference/cheatsheet.md',
  ])
    bundledDocumentation.firstWhere((page) => page.path == path).body,
].join('\n\n');

/// Bounded installed Dart examples selected by an edit's prompt and source.
/// Whole canonical pages are kept in stable order, up to 32 KiB of UTF-8;
/// private project content is never read by this documentation selector.
String dartEditingContext(String request) {
  final paths = <String>{
    if (RegExp('caption|subtitle|audio|music|sound', caseSensitive: false).hasMatch(request))
      'guides/audio-and-captions.md',
    if (RegExp('clip|image|media', caseSensitive: false).hasMatch(request))
      'guides/images-and-video-clips.md',
    'reference/cheatsheet.md',
  };
  var context =
      '# Fluvie $documentationVersion Dart API examples\n'
      'Corpus SHA-256: $documentationDigest. $_authoringInstructions';
  for (final path in paths) {
    final page = bundledDocumentation.firstWhere((page) => page.path == path);
    final next = '$context\n\n${page.body}';
    if (utf8.encode(next).length <= 32768) context = next;
  }
  return context;
}
