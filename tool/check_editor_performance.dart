import 'dart:convert';
import 'dart:io';

/// Rejects stale or incorrectly compiled performance evidence.
void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln('Usage: dart tool/check_editor_performance.dart <mode> <report.json>');
    exitCode = 64;
    return;
  }
  final report = jsonDecode(File(arguments[1]).readAsStringSync()) as Map<String, Object?>;
  final problems = performanceModeProblems(arguments[0], report);
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    exitCode = 1;
  } else {
    stdout.writeln('Performance report verified: ${arguments[0]} mode.');
  }
}

/// Build-mode constants come from the running Flutter program, not shell labels.
List<String> performanceModeProblems(String requested, Map<String, Object?> report) => [
  if (!{'debug', 'profile', 'release'}.contains(requested)) 'Unknown performance mode: $requested.',
  if (report['mode'] != requested)
    'Expected $requested performance evidence, received ${report['mode']}.',
  if (report['assertionsEnabled'] != (requested == 'debug'))
    'Incorrect assertion state for $requested: ${report['assertionsEnabled']}.',
];
