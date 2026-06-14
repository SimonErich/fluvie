// Fixture for the no_src_import unit test, placed under a lib/ path so the
// rule runs (it exempts non-lib files). Imports need not resolve to real
// packages; the rule only reads their URIs.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

// A cross-package src import: this is the violation.
import 'package:fluvie/src/core/time.dart';

// The public barrel of another package: allowed.
import 'package:fluvie/fluvie.dart';

// A relative import inside the same package: allowed.
import 'helper.dart';

void use() {}
