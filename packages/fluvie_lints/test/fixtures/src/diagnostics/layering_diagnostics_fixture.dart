// Fixture for the layering unit test. Its path ends in `src/diagnostics/`, so
// the rule treats it as the top diagnostics layer: nothing depends on it, and it
// may read every layer below, so no import here is ever flagged.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

// diagnostics importing a feature (rendering): downward, allowed.
import 'package:fluvie/src/rendering/frame.dart';

// diagnostics importing timing: downward, allowed.
import 'package:fluvie/src/timing/time_scope.dart';

// diagnostics importing core: downward, allowed.
import 'package:fluvie/src/core/time.dart';

void use() {}
