// Fixture: a pre-1.0 consolidated type name trips deprecated_member with a
// rename quick-fix. The 1.0 library has no such type, so the name is undefined
// here; the rule reads it syntactically.
// ignore_for_file: undefined_class, unused_local_variable

void build() {
  // expect_lint: deprecated_member
  VStack? legacyLayout;
}
