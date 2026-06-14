// Fixture for the deprecated_member unit test. The pre-1.0 names below do not
// exist in the 1.0 library, so the file does not resolve fully; the rule reads
// the bare type names syntactically.
// ignore_for_file: unused_local_variable, uri_does_not_exist, undefined_class

void build() {
  // A consolidated layout shim: flagged, rename to Stack.
  VStack? a;

  // A consolidated video shim: flagged, rename to Clip.
  EmbeddedVideo? b;

  // A composite shim: flagged, rename to Image (plus Animation.kenBurns).
  KenBurnsImage? c;

  // A current 1.0 name: never flagged.
  Stack? d;
}
