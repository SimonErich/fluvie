import 'dart:io';
import 'package:path/path.dart' as path;

/// An indexed document
class IndexedDocument {
  final String filePath;
  final String title;
  final String category;
  final String content;
  final List<String> keywords;
  final List<String> codeExamples;
  final List<String> sections;

  const IndexedDocument({
    required this.filePath,
    required this.title,
    required this.category,
    required this.content,
    required this.keywords,
    required this.codeExamples,
    required this.sections,
  });

  @override
  String toString() => 'IndexedDocument($title, $category)';
}

/// Document index containing all indexed documents
class DocIndex {
  final List<IndexedDocument> documents;

  const DocIndex({required this.documents});

  /// Get documents by category
  List<IndexedDocument> getByCategory(String category) {
    return documents.where((d) => d.category == category).toList();
  }

  /// Get all unique categories
  Set<String> get categories => documents.map((d) => d.category).toSet();
}

/// Indexes documentation files for search
class DocIndexer {
  final String docsPath;

  DocIndexer({required this.docsPath});

  /// Build the document index
  Future<DocIndex> buildIndex() async {
    final files = await _findMarkdownFiles();
    final documents = <IndexedDocument>[];

    for (final file in files) {
      try {
        final content = await File(file).readAsString();
        final parsed = _parseMarkdown(content);

        documents.add(
          IndexedDocument(
            filePath: file,
            title: parsed.title,
            category: _categorizeDocument(file),
            content: parsed.plainText,
            keywords: _extractKeywords(parsed.plainText),
            codeExamples: parsed.codeBlocks,
            sections: parsed.sections,
          ),
        );
      } catch (e) {
        // Skip files that can't be read
        continue;
      }
    }

    return DocIndex(documents: documents);
  }

  /// Find all markdown files in the docs directory
  Future<List<String>> _findMarkdownFiles() async {
    final dir = Directory(docsPath);
    if (!await dir.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        files.add(entity.path);
      }
    }

    return files;
  }

  /// Categorize a document based on its path
  String _categorizeDocument(String filePath) {
    final relativePath = path.relative(filePath, from: docsPath);

    if (relativePath.contains('widgets')) return 'widgets';
    if (relativePath.contains('templates')) return 'templates';
    if (relativePath.contains('animations')) return 'animations';
    if (relativePath.contains('effects')) return 'effects';
    if (relativePath.contains('getting-started') ||
        relativePath.contains('getting_started')) {
      return 'getting-started';
    }
    if (relativePath.contains('advanced')) return 'advanced';
    if (relativePath.contains('helpers')) return 'helpers';
    if (relativePath.contains('embedding')) return 'embedding';
    if (relativePath.contains('extending')) return 'extending';
    if (relativePath.contains('tutorials')) return 'tutorials';
    if (relativePath.contains('concept')) return 'concept';

    return 'general';
  }

  /// Parse markdown content
  _ParsedMarkdown _parseMarkdown(String content) {
    final lines = content.split('\n');
    String title = '';
    final sections = <String>[];
    final codeBlocks = <String>[];
    final plainTextBuffer = StringBuffer();

    bool inCodeBlock = false;
    final codeBuffer = StringBuffer();

    for (final line in lines) {
      // Check for code blocks
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          codeBlocks.add(codeBuffer.toString().trim());
          codeBuffer.clear();
        }
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      // Extract title from first H1
      if (title.isEmpty && line.startsWith('# ')) {
        title = line.substring(2).trim();
      }

      // Extract section headers
      if (line.startsWith('## ') || line.startsWith('### ')) {
        sections.add(line.replaceFirst(RegExp(r'^#+\s*'), '').trim());
      }

      // Add to plain text (excluding HTML tags and markdown syntax)
      final cleanLine = line
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
          .replaceAll(RegExp(r'[#*_`|]'), ' ')
          .trim();

      if (cleanLine.isNotEmpty) {
        plainTextBuffer.writeln(cleanLine);
      }
    }

    return _ParsedMarkdown(
      title: title.isEmpty ? 'Untitled' : title,
      plainText: plainTextBuffer.toString(),
      codeBlocks: codeBlocks,
      sections: sections,
    );
  }

  /// Extract keywords from text
  List<String> _extractKeywords(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .where((w) => !_stopWords.contains(w))
        .toList();

    return words;
  }

  /// Common stop words to filter out
  static const _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'been',
    'be', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
    'could', 'should', 'may', 'might', 'must', 'shall', 'can', 'need',
    'this', 'that', 'these', 'those', 'it', 'its', 'you', 'your', 'we',
    'our', 'they', 'their', 'what', 'which', 'who', 'whom', 'when',
    'where', 'why', 'how', 'all', 'each', 'every', 'both', 'few', 'more',
    'most', 'other', 'some', 'such', 'not', 'only', 'same', 'than',
    'too', 'very', 'just', 'also', 'now', 'here', 'there', 'then',
  };
}

class _ParsedMarkdown {
  final String title;
  final String plainText;
  final List<String> codeBlocks;
  final List<String> sections;

  const _ParsedMarkdown({
    required this.title,
    required this.plainText,
    required this.codeBlocks,
    required this.sections,
  });
}
