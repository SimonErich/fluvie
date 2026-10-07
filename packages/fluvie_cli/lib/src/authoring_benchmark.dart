import 'dart:convert';
import 'dart:io';

import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:path/path.dart' as p;

/// Runs a bounded authoring suite through the same command workflow as callers.
/// [execute] returns source and render verification evidence for each task.
/// Visual quality always remains a named human-review requirement.
Future<Map<String, Object?>> runAuthoringBenchmark({
  required Map<String, Object?> suite,
  required Directory output,
  required String provider,
  required String model,
  required bool realProvider,
  required Future<Map<String, Object?>> Function(Map<String, Object?> task, Directory output)
  execute,
}) async {
  final tasks = suite['cases'];
  if (suite['schemaVersion'] != 1 || tasks is! List || tasks.isEmpty || tasks.length > 20) {
    throw ArgumentError('Benchmark schema 1 requires 1..20 cases.');
  }
  final ids = <String>{};
  for (final task in tasks.cast<Map<String, Object?>>()) {
    final id = task['id'];
    final prompt = task['prompt'];
    if (id is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id) ||
        !ids.add(id) ||
        prompt is! String ||
        prompt.isEmpty ||
        prompt.length > 16384 ||
        !{'generate', 'edit', 'formats'}.contains(task['action'])) {
      throw ArgumentError(
        'Every case needs a unique safe id, bounded prompt and supported action.',
      );
    }
    for (final key in ['preserve', 'preserveRegions', 'requiredSourceText']) {
      if (task[key] != null &&
          (task[key] is! List || (task[key]! as List).any((v) => v is! String))) {
        throw ArgumentError('$key must contain strings.');
      }
    }
  }
  final results = <Map<String, Object?>>[];
  for (final task in tasks.cast<Map<String, Object?>>()) {
    final directory = Directory(p.join(output.path, task['id']! as String));
    await directory.create(recursive: true);
    await atomicWrite(p.join(directory.path, 'prompt.txt'), task['prompt']! as String);
    final watch = Stopwatch()..start();
    Map<String, Object?> result;
    try {
      final evidence = await execute(task, directory);
      final before = evidence['beforeSource'] as String?;
      final after = evidence['afterSource'] as String?;
      final preserve = ((task['preserve'] as List?) ?? const []).cast<String>();
      final requiredText = ((task['requiredSourceText'] as List?) ?? const []).cast<String>();
      final regions = ((task['preserveRegions'] as List?) ?? const []).cast<String>();
      final preserved =
          preserve.every(
            (text) => before?.contains(text) == true && after?.contains(text) == true,
          ) &&
          regions.every((region) {
            final original = _region(before, region);
            return original != null && original == _region(after, region);
          });
      final assets = requiredText.every((text) => after?.contains(text) == true);
      final changed = task['action'] != 'edit' || before != null && after != before;
      result = {
        ...evidence,
        'preserved': preserved,
        'requiredSourceTextPresent': assets,
        'sourceChanged': changed,
        'visualQuality': 'requires_human_review',
        'ok':
            evidence['ok'] == true &&
            evidence['renderVerified'] == true &&
            preserved &&
            assets &&
            changed,
      };
      if (before != null) await atomicWrite(p.join(directory.path, 'before.dart'), before);
      if (after != null) await atomicWrite(p.join(directory.path, 'after.dart'), after);
      result
        ..remove('beforeSource')
        ..remove('afterSource');
    } on Object catch (error) {
      result = {'ok': false, 'error': '$error', 'visualQuality': 'requires_human_review'};
    }
    result.addAll({
      'id': task['id'],
      'action': task['action'],
      'elapsedMilliseconds': watch.elapsedMilliseconds,
    });
    results.add(result);
    await atomicWrite(
      p.join(directory.path, 'case.json'),
      const JsonEncoder.withIndent('  ').convert(result),
    );
  }
  final report = <String, Object?>{
    'schemaVersion': 1,
    'provider': provider,
    'model': model,
    'realProvider': realProvider,
    'ok': results.every((result) => result['ok'] == true),
    'cases': results,
    'scope':
        'Compile/mount, source preservation assertions, selected-frame repeatability and encoded output verification. '
        'Required source text proves references, not semantic asset selection. Visual quality needs human review.',
  };
  await atomicWrite(
    p.join(output.path, 'benchmark.json'),
    const JsonEncoder.withIndent('  ').convert(report),
  );
  return report;
}

String? _region(String? source, String name) {
  if (source == null) return null;
  final startMarker = '// #docregion $name';
  final endMarker = '// #enddocregion $name';
  final start = source.indexOf(startMarker);
  if (start < 0) return null;
  final end = source.indexOf(endMarker, start + startMarker.length);
  return end < 0 ? null : source.substring(start, end + endMarker.length);
}
