import 'package:test/test.dart';

import '../check_pana.dart';

Map<String, Object?> report({
  String package = 'fluvie',
  String analyzer = '>=8.0.0 <9.0.0',
  int analysis = 50,
  int dependency = 40,
  String dependencySummary = '|[`analyzer`]|>=8.0.0 <9.0.0|8.4.0|**14.4.0**||',
}) => {
  'packageName': package,
  'pubspec': {
    'dependencies': {'analyzer': analyzer, 'custom_lint_builder': '^0.8.1'},
  },
  'report': {
    'sections': [
      for (final entry in {
        'convention': 30,
        'documentation': 20,
        'platform': 20,
        'analysis': 50,
        'dependency': 40,
      }.entries)
        {
          'id': entry.key,
          'maxPoints': entry.value,
          'grantedPoints': switch (entry.key) {
            'analysis' => analysis,
            'dependency' => dependency,
            _ => entry.value,
          },
          'summary': entry.key == 'dependency' ? dependencySummary : 'Details',
        },
    ],
  },
};

void main() {
  test('full scores pass and unrelated dependency or formatting losses fail', () {
    expect(panaProblems(report()), isEmpty);
    expect(panaProblems(report(dependency: 30)), isNotEmpty);
    expect(panaProblems(report(analysis: 40)), isNotEmpty);
  });
  test('the exact lint compatibility pin cannot hide another category regression', () {
    expect(panaProblems(report(package: 'fluvie_lints', dependency: 30)), isEmpty);
    expect(panaProblems(report(package: 'fluvie_lints', dependency: 30, analysis: 40)), isNotEmpty);
    expect(panaProblems(report(package: 'fluvie_lints', dependency: 20)), isNotEmpty);
    expect(
      panaProblems(report(package: 'fluvie_lints', analyzer: '^9.0.0', dependency: 30)),
      isNotEmpty,
    );
  });
  test('an incomplete report cannot accidentally pass', () {
    expect(panaProblems({}), isNotEmpty);
    expect(
      panaProblems({
        'report': {'sections': <Object?>[]},
      }),
      isNotEmpty,
    );
    expect(panaProblems(report(analysis: -1)), isNotEmpty);
  });
  test('the analyzer exception does not allow another stale dependency', () {
    expect(
      panaProblems(
        report(
          package: 'fluvie_lints',
          dependency: 30,
          dependencySummary:
              '|[`analyzer`]|>=8.0.0 <9.0.0|8.4.0|**14.4.0**||\n'
              '|[`custom_lint_builder`]|^0.8.1|0.8.1|**0.9.0**||',
        ),
      ),
      isNotEmpty,
    );
  });
}
