import 'dart:io';

import 'package:fluvie_server/src/mcp/init_tool.dart';
import 'package:test/test.dart';

/// The lockstep release version: every package under `packages/` ships the same
/// version, so the `fluvie` pin this tool advertises must track it.
String get _releaseVersion => RegExp(
  r'^version:\s*(.+)$',
  multiLine: true,
).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!.trim();

Future<String> _toolText() async =>
    (await buildInitProjectTool().handler(const {})).content.single['text']! as String;

void main() {
  group('init_project tool', () {
    test('is tagged for Flutter-style / real-code requests', () {
      final tool = buildInitProjectTool();
      expect(tool.name, 'init_project');
      expect(tool.description.toLowerCase(), contains('flutter style'));
      expect(tool.description.toLowerCase(), contains('real code'));
    });

    test('returns the starter, the deps, and the fluvie init command', () async {
      final result = await buildInitProjectTool().handler(const {});
      final text = result.content.single['text']! as String;

      expect(result.isError, isFalse);
      expect(text, contains('fluvie init'));
      expect(text, contains('Video build()'));
      expect(text, contains('fluvie: ^$_releaseVersion'));
      expect(text, contains('validate_code'));
    });

    test('teaches the entry point convention the CLI actually looks for', () async {
      // The composition is a top-level `Video build()`, not a named builder in
      // a registry: an assistant that emits `Video starterVideo()` writes a file
      // `fluvie render` finds no entry in.
      final text = await _toolText();

      expect(text, contains('Video build()'));
      expect(text, contains('--entry'));
      expect(text, isNot(contains('starterVideo')));
    });

    test('points render and preview at the composition file, not a registry key', () async {
      final text = await _toolText();

      expect(text, contains('fluvie preview ./lib/'));
      expect(text, contains('fluvie render ./lib/'));
    });

    test('says the composition belongs under lib/, which a preview requires', () async {
      // A preview app runs from outside the project and can only reach the
      // composition through its package URI, which only a file under lib/ has.
      final text = await _toolText();

      expect(text, contains('lib/'));
      expect(text.toLowerCase(), contains('assets'));
    });

    test('advertises no capture harness, registry, or app to maintain', () async {
      // The whole point of the single-file CLI: what the tool teaches must not
      // send an assistant off scaffolding the machinery the CLI now generates.
      final text = await _toolText();

      expect(text, isNot(contains('capture_harness_test.dart')));
      expect(text, isNot(contains('registerComposition')));
    });

    test('pins the fluvie version to the release, so the advice cannot rot', () async {
      // The tool tells an assistant what to put in a pubspec. If the pin lags
      // the release, the snippet resolves an older fluvie than the generated
      // harness needs.
      expect(await _toolText(), contains('fluvie: ^$_releaseVersion'));
    });
  });
}
