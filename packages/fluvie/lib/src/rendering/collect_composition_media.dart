import 'package:flutter/widgets.dart' show ProxyWidget, SingleChildRenderObjectWidget, Widget;
import 'package:fluvie/src/composition/runtime/generative_collector.dart'
    show collectGenerativeSources;
import 'package:fluvie/src/composition/runtime/media_collector.dart' show collectMediaSources;
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/contracts/generative_resolver.dart' show GenerativeResolver;
import 'package:fluvie/src/core/media/generative_source.dart' show GenerativeSource;
import 'package:fluvie/src/core/media/media_source.dart' show MediaSource;

/// Every declared [MediaSource] in [composition]'s scenes, or an empty set when
/// it wraps no [Video] — the collect pass a render's `preResolveAll` warms
/// before frame 0.
///
/// The `Video` is unwrapped through the transparent single-child wrappers a
/// render adds (an `AspectScope`, the `Directionality` `renderTemplate` adds),
/// so both a bare `Video` and a wrapped one resolve their media. Shared by the
/// file render and the in-browser sandbox render so the two never diverge.
Set<MediaSource> collectCompositionMedia(Widget composition, {GenerativeResolver? generative}) {
  final video = compositionVideo(composition);
  return video == null ? const {} : collectMediaSources(video.scenes, generative: generative);
}

/// Every declared [GenerativeSource] in [composition]'s scenes, or an empty set
/// when it wraps no [Video] — the generative collect pass a render's
/// `GenerativeResolver.generateAll` produces before media pre-resolution.
///
/// Unwraps the same transparent single-child wrappers as [collectCompositionMedia]
/// so a bare or wrapped `Video` resolves its generative declarations alike.
Set<GenerativeSource> collectCompositionGenerative(Widget composition) {
  final video = compositionVideo(composition);
  return video == null ? const {} : collectGenerativeSources(video.scenes);
}

/// The first [Video] at or below [composition], descending only the transparent
/// single-child wrappers (`InheritedWidget`s and single-child render objects an
/// `AspectScope` or `renderTemplate` adds); `null` when there is none. The clip
/// pre-pass reads the resolved [Video] so it plans at the video's own fps.
Video? compositionVideo(Widget composition) => switch (composition) {
  Video() => composition,
  ProxyWidget(:final child) => compositionVideo(child),
  SingleChildRenderObjectWidget(:final child?) => compositionVideo(child),
  _ => null,
};
