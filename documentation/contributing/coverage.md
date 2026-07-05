# Coverage and the ignore policy

Fluvie gates line coverage at 97% on every package under `packages/`. The goal
is 100%. This page explains when you may mark a line `// coverage:ignore`. It
also says when you must write a test instead.

Run the gate before you commit:

```sh
melos run coverage:check
```

It runs every package test with coverage. Then it checks the lcov reports
against the 97% floor. Generated files never count. Those are `*.g.dart`,
`*.freezed.dart`, and `*.mocks.dart`.

## The rule

Test behavior. Ignore only lines that have none. If a line does real work,
write a test that asserts the work. An ignore is a last resort.

Every ignore carries a reason on the same line. The gate honors three markers.

Write the reason in letters, digits, and spaces only. No colon after the
marker, no punctuation in the reason. `package:coverage` (the collector inside
`flutter test --coverage`) drops a marker on any other character, and an
unbalanced start and end pair crashes the whole test run. The tool test
`tool/test/coverage_ignore_syntax_test.dart` pins every marker to this charset.

Use an inline marker for one line:

<!-- code-excerpt-ignore: illustrates the coverage:ignore marker syntax, not runnable Fluvie API -->
```dart
final x = legacy(); // coverage:ignore-line reason here
```

Use a block marker for a run of lines:

<!-- code-excerpt-ignore: illustrates the coverage:ignore marker syntax, not runnable Fluvie API -->
```dart
// coverage:ignore-start reason here
... block ...
// coverage:ignore-end
```

Use a file marker for a whole file:

<!-- code-excerpt-ignore: illustrates the coverage:ignore marker syntax, not runnable Fluvie API -->
```dart
// coverage:ignore-file reason here
```

The gate reads the source and drops the marked lines from the total. Then it
recomputes the percentage. A reason is mandatory. A bare marker hides a gap, so
a reviewer must always see why.

## What you may ignore

Ignore a line only when no test could assert its behavior.

- **Const-constructor evaluation.** The VM does not instrument a `const Foo(...)`
  literal. Its constructor line reads as uncovered even when tests pin the
  object. Test the object's fields, equality, and `toString`. Then ignore the
  constructor line.
- **Diagnostic `toString` and `hashCode`.** Prefer a one-line test. Both are
  cheap to assert. Both guard debug output. Ignore them only when the type is
  private and the string never reaches a developer.
- **Platform, JS, and process glue.** Code that spawns FFmpeg cannot run in a
  unit test. Nor can a JS bridge or a real filesystem read. Cover its inputs and
  outputs with a fake. Then ignore the thin glue that calls the binary.
- **Defensive and unreachable arms.** A `default` arm or an `assert` stays for
  safety. A valid input can never reach it. Ignore it with a reason that names
  why it is unreachable.

## What you may never ignore

Never ignore a line that does real work. Write a test instead.

- A branch a real input can take. Drive both sides with two tests.
- A thrown error a caller can trigger. Assert the throw with `throwsA`.
- A calculation, a transform, or a state change. Assert the result.
- A whole file, unless it is a platform bridge that the VM cannot load.

A hard-to-test line is a design signal. It is not a license to ignore. Inject a
fake through a Riverpod override. Split the unit. Expose a pure helper. Report a
stubborn defect to the implementer rather than hiding it.

## Where to next

- [Testing guide](testing.md): how the suites and fakes fit together.
- [Contributing overview](overview.md): the workflow and the quality gate.
