// Fixture for the layering unit test. Its path ends in `src/core/`, so the
// rule treats it as a `core`-layer file: any upward import is a violation.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

// core importing timing: upward, forbidden.
import 'package:fluvie/src/timing/time_scope.dart';

// core importing a feature (rendering): upward, forbidden.
import 'package:fluvie/src/rendering/frame.dart';

// core importing another core file: same layer, allowed.
import 'package:fluvie/src/core/time.dart';

// a plain Flutter import: not a fluvie src import, allowed.
import 'package:flutter/widgets.dart';

void use() {}
