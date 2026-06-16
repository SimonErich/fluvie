import 'dart:io';

import 'package:fluvie_cli/src/render_defines.dart';
import 'package:test/test.dart';

void main() {
  group('specDefines', () {
    test('absolutizes the spec path under FLUVIE_RENDER_SPEC', () {
      final defines = specDefines('in.fluvie.json');
      expect(defines.keys, ['FLUVIE_RENDER_SPEC']);
      expect(defines['FLUVIE_RENDER_SPEC'], File('in.fluvie.json').absolute.path);
    });

    test('leaves an already-absolute path unchanged', () {
      final abs = File('in.fluvie.json').absolute.path;
      expect(specDefines(abs)['FLUVIE_RENDER_SPEC'], abs);
    });
  });

  group('generateDefines', () {
    test('carries the prompt and the absolutized spec-out', () {
      final defines = generateDefines(prompt: 'a coffee promo', specOut: 'out.fluvie.json');
      expect(defines['FLUVIE_AI_PROMPT'], 'a coffee promo');
      expect(defines['FLUVIE_RENDER_SPEC_OUT'], File('out.fluvie.json').absolute.path);
      expect(defines.containsKey('FLUVIE_AI_PROVIDER'), isFalse);
    });

    test('adds FLUVIE_AI_PROVIDER only for a non-empty provider', () {
      expect(
        generateDefines(prompt: 'p', specOut: 'o', provider: 'gemini')['FLUVIE_AI_PROVIDER'],
        'gemini',
      );
      expect(
        generateDefines(prompt: 'p', specOut: 'o', provider: '').containsKey('FLUVIE_AI_PROVIDER'),
        isFalse,
      );
    });
  });

  group('editDefines', () {
    test('carries the absolutized base spec, change and spec-out', () {
      final defines = editDefines(
        baseSpecPath: 'in.fluvie.json',
        change: 'make it blue',
        specOut: 'in.fluvie.json',
      );
      expect(defines['FLUVIE_AI_BASE_SPEC'], File('in.fluvie.json').absolute.path);
      expect(defines['FLUVIE_AI_PROMPT'], 'make it blue');
      expect(defines['FLUVIE_RENDER_SPEC_OUT'], File('in.fluvie.json').absolute.path);
      expect(defines.containsKey('FLUVIE_AI_PROVIDER'), isFalse);
    });

    test('adds FLUVIE_AI_PROVIDER only for a non-empty provider', () {
      expect(
        editDefines(
          baseSpecPath: 'b',
          change: 'c',
          specOut: 'o',
          provider: 'ollama',
        )['FLUVIE_AI_PROVIDER'],
        'ollama',
      );
      expect(
        editDefines(
          baseSpecPath: 'b',
          change: 'c',
          specOut: 'o',
          provider: '',
        ).containsKey('FLUVIE_AI_PROVIDER'),
        isFalse,
      );
    });
  });
}
