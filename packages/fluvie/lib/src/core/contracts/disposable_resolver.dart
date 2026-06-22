/// A media resolver that holds disposable native resources (decoded images) and
/// can release them eagerly instead of waiting for garbage collection.
///
/// The render pipeline disposes a resolver it *owns* (one it built per render
/// from `mediaResolverProvider`) once the render is done; an injected resolver
/// belongs to the caller and is never disposed by the pipeline.
// A capability marker, queried with `is DisposableResolver` so the pipeline
// disposes only resolvers that hold native resources — not a single-method
// utility that would fit a top-level function.
// ignore: one_member_abstracts
abstract interface class DisposableResolver {
  /// Releases cached native resources. Safe to call more than once.
  void dispose();
}
