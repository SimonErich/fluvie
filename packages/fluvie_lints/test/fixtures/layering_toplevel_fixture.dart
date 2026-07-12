// Fixture for the layering unit test. Its path is not inside a `src/<layer>/`
// tree, so the rule cannot read a layer and stays silent (the conservative
// direction), even on an import that would look upward from a real layer.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

import 'package:fluvie/src/diagnostics/inspector_model.dart';

void use() {}
