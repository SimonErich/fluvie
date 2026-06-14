import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:fluvie_lints/fluvie_lints.dart';
import 'package:test/test.dart';

void main() {
  group('createPlugin', () {
    final plugin = createPlugin();
    final rules = plugin.getLintRules(
      // ignore: invalid_use_of_internal_member, the only way to call the plugin contract in a unit test
      CustomLintConfigs.empty,
    );

    test('declares exactly the ten Fluvie rules', () {
      expect(plugin, isA<PluginBase>());
      final names = rules.map((r) => r.code.name).toSet();
      expect(
        names,
        unorderedEquals(<String>[
          'no_src_import',
          'layering',
          'nondeterministic_random',
          'deprecated_member',
          'dangling_anchor',
          'cyclic_trigger',
          'unused_anchor',
          'animation_exceeds_window',
          'conflicting_keyframe_fields',
          'relative_outside_scope',
        ]),
      );
      expect(rules, hasLength(10));
    });

    test('every rule code name is unique', () {
      final names = rules.map((r) => r.code.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('the three fixable rules expose a quick-fix; the rest do not', () {
      final fixable = <String>{};
      for (final rule in rules) {
        if (rule.getFixes().isNotEmpty) fixable.add(rule.code.name);
      }
      expect(
        fixable,
        unorderedEquals(<String>[
          'no_src_import',
          'deprecated_member',
          'unused_anchor',
        ]),
      );
    });
  });
}
