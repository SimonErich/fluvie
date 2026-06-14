// Fixture: this file's path ends in src/core/, so the layering rule treats it
// as a core-layer file. A core file importing the timing layer points up, which
// the layering law forbids. Because the import is also a cross-package src
// import, no_src_import fires on the same line (defense in depth), so both
// codes are expected.
// ignore_for_file: implementation_imports, unused_import, depend_on_referenced_packages

// expect_lint: layering, no_src_import
import 'package:fluvie/src/timing/time_scope_data.dart';

void use() {}
