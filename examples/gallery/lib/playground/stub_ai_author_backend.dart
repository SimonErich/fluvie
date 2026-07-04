import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_example/playground/server_ai_author_backend.dart';

/// Builds the AI Assistant's backend from the build-time `FLUVIE_API_URL`.
///
/// When a server is configured the demo authors through it (the server holds the
/// provider key and enforces the quota — the browser can do neither). With no
/// server it falls back to a prompt-responsive [StubAiAuthorBackend] that runs
/// entirely in the browser, so the whole flow stays testable offline.
AiAuthorBackend createAiAuthorBackend() {
  const apiUrl = String.fromEnvironment('FLUVIE_API_URL');
  if (apiUrl.isEmpty) return StubAiAuthorBackend();
  const token = String.fromEnvironment('FLUVIE_API_TOKEN');
  return ServerAiAuthorBackend(baseUrl: Uri.parse(apiUrl), token: token.isEmpty ? null : token);
}

/// A local, offline stand-in for real AI code generation.
///
/// It turns a prompt into a valid `Video build()` title card: the prompt becomes
/// the headline and a colour keyword (such as "red" or "ocean") picks the
/// gradient. An edit keeps the existing headline and just restyles by the new
/// prompt, so "make it red" behaves as expected. It always returns compilable
/// Fluvie code, so the generate -> validate -> render flow works end to end
/// while the real model is wired up.
final class StubAiAuthorBackend implements AiAuthorBackend {
  /// Creates the stub; [latency] simulates think time so loading states show.
  StubAiAuthorBackend({this.latency = const Duration(milliseconds: 1200)});

  /// Simulated generation latency, so the UI's loading state is observable. Set
  /// to [Duration.zero] in tests.
  final Duration latency;

  @override
  Future<AiAuthorResult> author(String prompt, {String? currentCode}) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    // On an edit, keep what the user already has and only restyle; on a fresh
    // request the prompt becomes the headline.
    final headline = currentCode == null
        ? _headline(prompt)
        : _extractHeadline(currentCode) ?? _headline(prompt);
    final (top, bottom) = _gradientFor(prompt);
    return AiAuthorResult(
      code: _videoSource(headline: headline, top: top, bottom: bottom),
    );
  }
}

/// Escapes [prompt] into the headline of a single-quoted Dart string, collapsing
/// whitespace and capping the length so the title stays readable.
String _headline(String prompt) {
  final cleaned = prompt.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty) return 'Your Fluvie video';
  final capped = cleaned.length > 48 ? '${cleaned.substring(0, 48)}...' : cleaned;
  return _escape(capped);
}

/// Escapes the backslash, single quote, and dollar so [text] is safe inside a
/// single-quoted Dart string literal.
String _escape(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');

/// Pulls the already-escaped headline out of generated code, so an edit can
/// preserve it. Returns null when no `Text('...')` is found.
String? _extractHeadline(String code) =>
    RegExp(r"Text\(\s*'((?:[^'\\]|\\.)*)'").firstMatch(code)?.group(1);

/// Picks a gradient (two `0xFF...` hex literals) from colour words in [prompt].
(String, String) _gradientFor(String prompt) {
  final p = prompt.toLowerCase();
  if (_has(p, const ['red', 'fire', 'sunset', 'warm'])) return ('0xFFE53935', '0xFFFF8A65');
  if (_has(p, const ['green', 'forest', 'nature', 'mint'])) return ('0xFF11998E', '0xFF38EF7D');
  if (_has(p, const ['purple', 'galaxy', 'night', 'cosmic'])) return ('0xFF6A11CB', '0xFF2575FC');
  if (_has(p, const ['dark', 'black', 'noir'])) return ('0xFF232526', '0xFF414345');
  if (_has(p, const ['gold', 'lux', 'premium'])) return ('0xFFB8860B', '0xFFFFD700');
  return ('0xFF1A2980', '0xFF26D0CE'); // ocean blue, the default
}

bool _has(String haystack, List<String> needles) => needles.any(haystack.contains);

/// Assembles a known-valid `Video build()` with the given [headline] and
/// gradient stops.
String _videoSource({required String headline, required String top, required String bottom}) =>
    '''
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Video build() {
  return Video(
    size: VideoSize.square,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color($top), Color($bottom)]),
        children: [
          const Text(
            '$headline',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.bold,
            ),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
''';
