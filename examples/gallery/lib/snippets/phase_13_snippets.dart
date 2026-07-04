// Compiled, tested snippets for the diagrams-and-webviews doc. They live here,
// not hand-typed in Markdown, so the documentation never drifts from a real
// API. Each `#docregion` flows into one fence via a `<!-- code-excerpt -->`
// marker.

// Mermaid, Html, and WebView are @experimental by design; these snippets exist
// to document them, so the experimental-use warning is
// expected here. The reference menus spell out the default reveal and write a
// non-const Html so the docs read as plain API, which trips the const/redundant
// lints — fine for documentation samples.
// ignore_for_file: experimental_member_use, avoid_redundant_argument_values
// ignore_for_file: prefer_const_constructors
import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

/// `Snapshot` rasterizes any Flutter subtree once, before frame 0, then paints
/// the still every frame — deterministic and gate-safe.
Widget rasterizedCard() =>
    // #docregion snapshot
    Snapshot(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFF1E2A36),
          child: const Text('rasterized once'),
        ),
      ),
    );
// #enddocregion snapshot

/// `Mermaid` renders a diagram from its source string; the source is the only
/// required input.
Mermaid simpleDiagram() =>
    // #docregion mermaid
    const Mermaid('graph LR; A --> B; B --> C;');
// #enddocregion mermaid

/// Two `MermaidTheme` presets ship; pass one to `theme`.
List<Mermaid> mermaidThemes(String source) => [
  // #docregion mermaid-theme
  Mermaid(source, theme: const MermaidTheme.dark()),
  Mermaid(source, theme: const MermaidTheme.light()),
  // #enddocregion mermaid-theme
];

/// `reveal` is a `MermaidReveal` with three modes.
List<Mermaid> mermaidReveals(String src) => [
  // #docregion mermaid-reveal
  Mermaid(src, reveal: MermaidReveal.none), // the whole diagram at once (default)
  Mermaid(src, reveal: MermaidReveal.fadeNodes(1.seconds)), // nodes fade in over the window
  Mermaid(src, reveal: MermaidReveal.drawEdges(1.seconds)), // edges draw on over the window
  // #enddocregion mermaid-reveal
];

/// `Html` renders an inline string; `WebView.url` captures a live page. Both
/// snapshot a viewport, then paint the still (a network allowlist applies).
List<Widget> webSnapshots() => [
  // #docregion webview
  Html('<h1>fluvie.dev</h1>', viewport: const SnapshotViewport(width: 720, height: 405)),
  WebView.url('https://fluvie.dev', viewport: const SnapshotViewport(width: 1280, height: 720)),
  // #enddocregion webview
];
