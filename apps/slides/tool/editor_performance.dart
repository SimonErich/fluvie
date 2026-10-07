import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode, kReleaseMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show MediaSource;
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:integration_test/integration_test.dart';
import 'package:obers_ui/obers_ui.dart';

import 'editor_performance_metrics.dart';
import 'editor_performance_workspace.dart';

part 'editor_performance_document.part.dart';
part 'editor_performance_interactions.part.dart';
part 'editor_performance_media.part.dart';

const _source = String.fromEnvironment('FLUVIE_PERF_CLIP');
const _report = String.fromEnvironment('FLUVIE_PERF_REPORT');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Release has no VM service/driver connection. The standalone runner exits
  // only after the actual test verdict, so a failed assertion fails the script.
  if (kReleaseMode) {
    unawaited(binding.allTestsPassed.future.then((passed) => exit(passed ? 0 : 1)));
  }
  testWidgets(
    'measure three-minute 4K editor workload and proxy scrubbing',
    (tester) async {
      final workload = _measureDocument();
      final results = workload.results;
      final document = workload.document;
      await _measureTimeline(tester, workload.model, results);
      await _measureCanvas(tester, document, results);
      results['fullEditor'] = await measureEditorWorkspace(tester, document);
      await _measureDecodeTiers(tester, results);
      await _measurePreview(tester, document, results);
      binding.reportData = results;
      final encoded = const JsonEncoder.withIndent('  ').convert(results);
      if (_report.isNotEmpty) File(_report).writeAsStringSync(encoded);
      // Captured by the QA log as well as the structured report.
      // ignore: avoid_print, this explicit benchmark is a reporting tool
      print(encoded);
    },
    skip: _source.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
