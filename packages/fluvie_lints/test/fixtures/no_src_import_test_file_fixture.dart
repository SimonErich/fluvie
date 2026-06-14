// Fixture for the no_src_import test: a cross-package src import in a test
// file (path outside lib/). The rule must NOT fire here — test files are
// exempt so integration harnesses can access render internals.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

import 'package:fluvie/src/core/time.dart';

void use() {}
