import 'package:fluvie/src/core/contracts/generative_resolver.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';
import 'package:riverpod/riverpod.dart';

/// The active [GenerativeResolver] for a render.
///
/// Defaults to the [NoGenerativeResolver] (a no-op when nothing in the tree is
/// generated, a clear error otherwise), so the standard Fluvie flow is
/// unaffected and pays nothing. Override it with `fluvie_ai`'s resolver to
/// produce `Generative*` media; tests override it with a fake.
final generativeResolverProvider = Provider<GenerativeResolver>(
  (ref) => const NoGenerativeResolver(),
);
