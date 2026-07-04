// Compiled, tested snippets for the code-and-terminal-videos doc. They live
// here, not hand-typed in Markdown, so the documentation never drifts from a
// real API. Each `#docregion` flows into one fence via a `<!-- code-excerpt -->`
// marker.

// These reference snippets spell out the default reveal, keep the focus-line
// set literals, and write the unprefixed-const FluvieTokensScope so the docs
// read as plain API. That trips the const/redundant-value lints, which is fine
// for documentation samples (the real lessons keep the const-correct forms).
// ignore_for_file: avoid_redundant_argument_values, prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// `Code` highlights a source string in a named highlight.js language.
List<Code> codeLanguages() => const [
  // #docregion code-languages
  Code('def main():\n    print("hi")', language: 'python'),
  Code('const x = 1;', language: 'javascript'),
  Code('SELECT * FROM users;', language: 'sql'),
  // #enddocregion code-languages
];

/// `reveal` is a `CodeReveal` with three modes.
List<Code> codeReveals(String src) => [
  // #docregion code-reveal
  Code(src, reveal: CodeReveal.instant), // everything at once (default)
  Code(src, reveal: CodeReveal.typing(2.frames)), // glyph by glyph, with a caret
  Code(src, reveal: CodeReveal.lineByLine(8.frames)), // whole lines in sequence
  // #enddocregion code-reveal
];

/// `focusLines` dims every other line; `highlightLines` tints those lines.
Code focusedCode(String src) =>
    // #docregion code-focus
    Code(src, language: 'dart', focusLines: {3, 4}, highlightLines: {4});
// #enddocregion code-focus

/// A `Code` themed by a `FluvieTokensScope`: every `Code` and `Terminal` inside
/// reads the scope's `code` theme.
Widget themedCode() =>
    // #docregion code-tokens
    FluvieTokensScope(
      tokens: const FluvieTokens.fallback(),
      child: const Code('void main() {}', language: 'dart'),
    );
// #enddocregion code-tokens

/// An animated `before -> after` line diff.
Code diffCode() =>
    // #docregion code-diff
    Code.diff(
      'final x = 1;',
      'final x = 2;',
      language: 'dart',
      reveal: CodeReveal.lineByLine(12.frames),
    );
// #enddocregion code-diff

/// `Markdown` renders a document: headings, lists, blockquotes, and inline
/// `code`, **bold**, and *italic*.
Markdown releaseNotes() =>
    // #docregion markdown
    const Markdown(
      '# Release notes\n\n'
      '- Faster renders\n'
      '- Highlighted `Code` blocks\n\n'
      '> On-device rendering is the headline.',
    );
// #enddocregion markdown

/// `reveal` shows the document block by block over the element window.
Markdown revealedMarkdown(String source) =>
    // #docregion markdown-reveal
    Markdown(source, reveal: 1.seconds);
// #enddocregion markdown-reveal
