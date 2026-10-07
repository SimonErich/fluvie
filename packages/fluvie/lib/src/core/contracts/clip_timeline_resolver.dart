import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie_media/fluvie_media.dart' show MediaTimeline;

/// Optional exact source-clock capability, preserving legacy media resolvers.
// ignore: one_member_abstracts — resolvers opt into the source-clock capability without changing the legacy interface.
abstract interface class ClipTimelineResolver {
  /// The prepared display timeline for [source], or null for constant-rate
  /// fallback. Only call after the resolver has probed the clip.
  MediaTimeline? clipTimelineFor(MediaSource source);
}

/// Reads exact source timing when [resolver] advertises the optional capability.
MediaTimeline? clipTimelineFor(MediaResolver resolver, MediaSource source) =>
    resolver is ClipTimelineResolver
    ? (resolver as ClipTimelineResolver).clipTimelineFor(source)
    : null;
