// Fixture: importing another package's src/ trips no_src_import. The dart
// implementation_imports lint flags the same line; the custom rule owns the
// Fluvie message and the barrel quick-fix.
// ignore_for_file: implementation_imports, unused_import, depend_on_referenced_packages

// expect_lint: no_src_import
import 'package:fluvie/src/core/time.dart';

void use() {}
