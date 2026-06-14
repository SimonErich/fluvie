// Fixture under a `lib/` path so no_src_import can read the owning package name
// (the directory segment before /lib/ is `fixtures`). A same-package src import
// is the library's own wiring and is allowed; a different package's is flagged.
// ignore_for_file: unused_import, uri_does_not_exist, depend_on_referenced_packages

// Same package (fixtures) src import: allowed.
import 'package:fixtures/src/internal.dart';

// Different package src import: flagged.
import 'package:fluvie/src/core/time.dart';

void use() {}
