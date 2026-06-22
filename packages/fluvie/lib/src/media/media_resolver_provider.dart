/// The platform media resolver provider wiring.
///
/// Resolves to a `dart:io`-backed `MediaRepository` (images, clips, audio,
/// snapshots, captions) on native platforms, and to a `dart:io`-free
/// `WebImageMediaResolver` (images only) in the browser. The conditional export
/// is what lets a web build reference `mediaResolverProvider` without pulling
/// `dart:io` into the program.
library;

export 'media_resolver_provider_io.dart'
    if (dart.library.js_interop) 'media_resolver_provider_web.dart';
