// Fixture for the layering unit test. Its path ends in `src/timing/`, so the
// rule treats it as a `timing`-layer file: it may import core, but a feature
// layer or diagnostics is an upward or sideways break.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

// timing importing a feature (rendering): upward, forbidden.
import 'package:fluvie/src/rendering/frame.dart';

// timing importing diagnostics: sideways into the top, forbidden.
import 'package:fluvie/src/diagnostics/inspector_model.dart';

// timing importing core: downward, allowed.
import 'package:fluvie/src/core/time.dart';

void use() {}
