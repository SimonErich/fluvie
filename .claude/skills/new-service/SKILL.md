---
name: new-service
description: Scaffold a Fluvie service the house way — abstract contract, implementation, Riverpod provider, in-memory fake, and unit test. Use when adding any service/repository (media, encoding, capture, beat detection, snapshot, ...).
---

# new-service

Services hold logic with IO or computation behind an abstract contract, injected
via Riverpod and overridable with a fake in tests. Widgets/ViewModels never do IO
directly.

## Steps

1. **Contract** — `packages/fluvie/lib/src/<layer>/<snake_name>.dart`: an abstract
   class with documented methods. Place pure exceptions in `core` (e.g. `FluvieEncodeException`).
2. **Implementation** — `<snake_name>_impl.dart` (or a platform-specific file): the
   real logic. FFmpeg/process work builds **argument lists**, validates input, and
   sandboxes temp dirs. No upward/cross-`src/` imports.
3. **Provider** — a Riverpod provider exposing the contract, defaulting to the impl.
4. **Fake** — `test/<layer>/fakes/fake_<snake_name>.dart`: deterministic in-memory
   stand-in (also serves as the seam's tested fake).
5. **Unit test (written first)** — covers the contract via the impl and/or fake;
   deterministic. Use **mocktail** (`class _MockX extends Mock implements X`) for
   interaction verification; inject via `ProviderContainer(overrides: [...])`.
6. **Gate** — `melos run gate` green; commit `feat(<layer>): add <Name>Service`.

## Template

```dart
// <layer>/<snake_name>.dart
/// {What this service does and its determinism/security guarantees.}
abstract interface class <Name>Service {
  /// {Method contract.}
  Future<Result> doThing(Input input);
}

// <layer>/<snake_name>_impl.dart
final class <Name>ServiceImpl implements <Name>Service {
  const <Name>ServiceImpl();
  @override
  Future<Result> doThing(Input input) async {
    // validate input; never shell-concatenate; deterministic output.
    // (Write the real minimal body here; never ship UnimplementedError.)
  }
}

// provider (Riverpod)
final <camelName>ServiceProvider = Provider<<Name>Service>(
  (ref) => const <Name>ServiceImpl(),
);
```

```dart
// test fake
final class Fake<Name>Service implements <Name>Service {
  @override
  Future<Result> doThing(Input input) async => /* canned deterministic result */;
}
```
