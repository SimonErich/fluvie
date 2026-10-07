import 'dart:convert';
import 'dart:io';

/// Checks the publishability report without allowing a dependency exception to
/// hide formatting, analysis, documentation or platform regressions.
void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart tool/check_pana.dart <pana-report.json>');
    exitCode = 64;
    return;
  }
  final report = jsonDecode(File(arguments.single).readAsStringSync()) as Map<String, Object?>;
  final problems = panaProblems(report);
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    exitCode = 1;
  } else {
    stdout.writeln('${report['packageName']}: publishability checks passed.');
  }
}

/// Full points are required in every category, except the documented analyzer
/// 8 compatibility pin in fluvie_lints, which may cost ten dependency points.
List<String> panaProblems(Map<String, Object?> report) {
  final package = report['packageName'];
  final pubspec = report['pubspec'] as Map<String, Object?>?;
  final dependencies = pubspec?['dependencies'] as Map<String, Object?>?;
  final permitAnalyzerPin =
      package == 'fluvie_lints' &&
      dependencies?['analyzer'] == '>=8.0.0 <9.0.0' &&
      dependencies?['custom_lint_builder'] == '^0.8.1';
  final sections = (report['report'] as Map<String, Object?>?)?['sections'];
  if (sections is! List<Object?>) return ['Missing pana report sections.'];
  final missing = {'analysis', 'convention', 'dependency', 'documentation', 'platform'};
  final problems = <String>[];
  for (final section in sections.whereType<Map<String, Object?>>()) {
    final id = section['id'];
    missing.remove(id);
    final granted = section['grantedPoints'];
    final maximum = section['maxPoints'];
    if (granted is! int || maximum is! int || maximum < 1 || granted > maximum || granted < 0) {
      problems.add('$package: invalid score for $id.');
      continue;
    }
    // Pana is pinned in verify_packages.sh. Its direct-dependency table marks
    // unsupported latest versions in bold; transitive rows follow <details>.
    // Refuse any other stale direct dependency, even if it costs the same ten
    // points, so a new builder release requires a deliberate compatibility review.
    final summary = section['summary'] as String? ?? '';
    final stale = RegExp(
      r'^\|\[`([^`]+)`\]\|[^\n]+\|\*\*[^|]+\*\*\|',
      multiLine: true,
    ).allMatches(summary.split('<details>').first).map((match) => match.group(1)).toSet();
    final allowed =
        id == 'dependency' && permitAnalyzerPin && stale.length == 1 && stale.single == 'analyzer'
        ? 10
        : 0;
    if (maximum - granted > allowed) {
      problems.add('$package: $id scored $granted/$maximum. ${section['summary']}');
    }
  }
  if (missing.isNotEmpty) problems.add('$package: missing categories: ${missing.join(', ')}.');
  return problems;
}
