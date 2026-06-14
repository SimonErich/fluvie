// Fixture for the layering unit test. Its path ends in `src/rendering/`, so the
// rule treats it as a feature-layer file: importing diagnostics is forbidden,
// but importing core/timing is fine.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

// a feature importing diagnostics: forbidden.
import 'package:fluvie/src/diagnostics/inspector_model.dart';

// a feature importing core: downward, allowed.
import 'package:fluvie/src/core/time.dart';

// a feature importing timing: downward, allowed.
import 'package:fluvie/src/timing/time_scope.dart';

void use() {}
