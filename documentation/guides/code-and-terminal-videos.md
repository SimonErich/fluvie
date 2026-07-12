# Code and terminal videos

Show source the way a screencast does: type it out, highlight the lines that
matter, then run it in a terminal. `Code` and `Terminal` are frame-driven
elements, so you describe the content and the reveal happens for you:

<!-- code-excerpt "examples/gallery/lib/lessons/08_code_doc_intro.dart (code)" -->
```dart
child: Code(
  _snippet,
  language: 'dart',
  reveal: CodeReveal.typing(1.frames),
  focusLines: const {5},
  highlightLines: const {5},
).animate([Animation.slideFadeIn()]),
```

That highlights the snippet in Dart, types it out one glyph per frame, dims
every line except line 5, and tints line 5's background. The reveal is built in;
`.animate()` only adds the outer slide. Lesson 08 builds the whole explainer.

## Code

`Code` takes the source as its first argument and the highlight language as
`language`. The source is highlighted once per content and cached by content
hash, so frame N never re-parses and the same frame paints the same pixels every
time. The highlighter is the highlight.js Dart port, which covers around 190
languages:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (code-languages)" -->
```dart
Code('def main():\n    print("hi")', language: 'python'),
Code('const x = 1;', language: 'javascript'),
Code('SELECT * FROM users;', language: 'sql'),
```

An unknown language renders the source as plain, unhighlighted text rather than
throwing.

### Reveal modes

`reveal` is a `CodeReveal` and has three modes:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (code-reveal)" -->
```dart
Code(src, reveal: CodeReveal.instant), // everything at once (default)
Code(src, reveal: CodeReveal.typing(2.frames)), // glyph by glyph, with a caret
Code(src, reveal: CodeReveal.lineByLine(8.frames)), // whole lines in sequence
```

`typing` reveals the joined source one glyph at a time and blinks a caret while
it runs, reusing the same arithmetic `Typewriter` does. `lineByLine` reveals
whole lines in turn: line `i` appears once the elapsed frames pass `i` times the
per-line time. Each mode carries a `Time` that resolves against the element
window, so a relative time scales with the scene.

### Focus and highlight

`focusLines` and `highlightLines` are sets of 1-based line numbers. `focusLines`
dims every other line to the theme's dim opacity, so the eye lands on the lines
you name. `highlightLines` tints those lines' backgrounds:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (code-focus)" -->
```dart
Code(src, language: 'dart', focusLines: {3, 4}, highlightLines: {4});
```

Both are content parameters, so the frame clock and scene placement drive which
focus is active. To move the focus over time, re-issue the `Code` with a
different set at the next scene or timeline position, the way a chart re-issues
its data. A cross-fade between two focus states is a plain
`.animate([Animation.fadeIn()])` on the swapped widget.

### Theming with context.fluvie

`Code` reads its colors from `context.fluvie.code`, a `CodeTheme` that maps every
token kind to a color and carries the editor background, gutter, line-number, dim
opacity, and highlight colors. Wrap a subtree in a `FluvieTokensScope` to theme
every `Code` and `Terminal` inside it:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (code-tokens)" -->
```dart
FluvieTokensScope(
  tokens: const FluvieTokens.fallback(),
  child: const Code('void main() {}', language: 'dart'),
);
```

A `Code(theme:)` override wins over the inherited theme for that one element. Ship
`CodeTheme.dark()` or `CodeTheme.light()`, or build a custom theme.

### Code.diff

`Code.diff(before, after)` animates the change from one version to another over a
pure line diff: removed lines fade out and collapse behind a red gutter, inserted
lines fade in and expand behind a green gutter, and kept lines slide to their new
position:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (code-diff)" -->
```dart
Code.diff(
  'final x = 1;',
  'final x = 2;',
  language: 'dart',
  reveal: CodeReveal.lineByLine(12.frames),
);
```

Both sides are highlighted once and cached, so the diff colors its tokens too.

## Terminal

`Terminal` plays a list of `TerminalLine` values in sequence. A `cmd` line types
out glyph by glyph after a prompt with a blinking caret; an `out` line streams in
whole once its turn arrives:

<!-- code-excerpt "examples/gallery/lib/lessons/08_code_doc_intro.dart (terminal)" -->
```dart
child: const Terminal(
  chrome: TerminalChrome.macos(title: 'zsh'),
  lines: [
    TerminalLine.cmd('dart run fluvie render hello'),
    TerminalLine.out('Rendering 270 frames...'),
    TerminalLine.out('Wrote hello.mp4 (9.0s, 1080x1080)'),
  ],
).animate([Animation.slideFadeIn()]),
```

The prompt is `$ ` by default; pass `prompt:` to change it for the whole
terminal, or `TerminalLine.cmd('...', prompt: '> ')` for one line. `typingSpeed`
sets how fast a command types and `lineGap` sets how long after one line settles
the next begins. Each line reveals in sequence with the same stagger machinery a
multi-child `.animate()` uses.

`chrome` adds an optional window bar. `TerminalChrome.macos(title:)` draws a
title and the three traffic-light dots; leave `chrome` null for a bare terminal.
Terminal colors come from `context.fluvie.code` too.

## Markdown

`Markdown` parses a CommonMark document once and renders it to widgets: headings,
paragraphs, lists, blockquotes, and inline `code`, **bold**, and *italic* runs.

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (markdown)" -->
```dart
const Markdown(
  '# Release notes\n\n'
  '- Faster renders\n'
  '- Highlighted `Code` blocks\n\n'
  '> On-device rendering is the headline.',
);
```

A fenced code block in the source delegates to a `Code` widget highlighted in
its fence language, and an image delegates to an `Image` widget, so the same
highlighting and pre-resolved media you use elsewhere apply inside a document.
The rest of the source, headings, paragraphs, and lists, renders as styled text.

Pass `reveal:` a `Time` to bring the top-level blocks in one after another over
the element window:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_12_snippets.dart (markdown-reveal)" -->
```dart
Markdown(source, reveal: 1.seconds);
```

Each block fades and slides up as its turn arrives. With no `reveal` the whole
document shows at once. Colors follow `context.fluvie`, or pass a `MarkdownStyle`
to `style:`.

## The bundled font

`Code`, `Terminal`, and the fenced blocks inside `Markdown` default their font to
JetBrains Mono, bundled with the package. You do not register anything: the font
ships to every render, so your monospace text looks the same on every machine.
Pass a `style:` with your own `fontFamily` to override it.

## Parsed once, cached by content

Every one of these elements is a pure function of its parsed content, its reveal
progress, and its theme tokens. The parse and the highlight run once per content
and are cached by content hash, never per frame. The same frame paints the same
way every time, so code, terminal, and Markdown videos cache and golden like
every other element.

## Where to next

- [Text and typography](text-and-typography.md): `Typewriter` and `Counter`, the
  text elements a code explainer sits beside.
- [Charts and data](charts-and-data.md): the other data-driven element family,
  with the same reveal-is-intrinsic contract.
