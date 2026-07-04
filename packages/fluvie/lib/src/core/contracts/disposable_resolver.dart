/// A media resolver that holds disposable native resources (decoded images) and
/// can release them eagerly instead of waiting for garbage collection.
///
/// The render pipeline disposes a resolver it *owns* (one it built per render
/// from `mediaResolverProvider`) once the render is done; an injected resolver
/// belongs to the caller and is never disposed by the pipeline.
// ignore: one_member_abstracts — a capability marker queried with `is`, not a utility function.
abstract interface class DisposableResolver {
  /// Releases cached native resources. Safe to call more than once.
  void dispose();
}
