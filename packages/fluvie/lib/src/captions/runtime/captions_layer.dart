import 'package:flutter/widgets.dart';
import 'package:fluvie/src/captions/caption_position.dart';
import 'package:fluvie/src/captions/captions.dart';
import 'package:fluvie/src/captions/runtime/caption_active_cue.dart';
import 'package:fluvie/src/captions/runtime/caption_cue_view.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/theme/build_context_tokens.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The scene-spanning caption overlay: one per `Video`, mounted above the
/// composition, showing the active cue at the current frame.
///
/// The layer reads the resolved cues from the nearest [ImageResolverScope] (the
/// render shell pre-parsed them before frame 0), the current frame from
/// [FrameProvider], and the time scope from [TimeScopeProvider]; it picks the
/// cue whose window contains the frame and renders it styled (the track's
/// `style`, or the theme's `captions.defaultStyle`) and positioned (the track's
/// `position`, or the bottom third). Outside every cue it draws nothing.
///
/// It wraps no media, so it is deliberately **not** a `CollectibleChildren`.
/// Word-pop and karaoke reuse the shared stagger and Animation progress math
/// (no bespoke caption animation) in the cue view.
///
/// In a live preview there is usually no resolver scope, so the layer shows
/// nothing rather than reading or parsing a file mid-frame.
final class CaptionsLayer extends StatelessWidget {
  /// Creates the overlay for the [captions] track.
  const CaptionsLayer({required this.captions, super.key});

  /// The caption track to render.
  final Captions captions;

  @override
  Widget build(BuildContext context) {
    final resolver = ImageResolverScope.maybeOf(context);
    if (resolver == null) return const SizedBox.shrink();
    final scope = TimeScopeProvider.of(context);
    final frame = FrameProvider.of(context).frame;
    final cue = activeCue(resolver.cuesFor(captions.captionSource), frame: frame, scope: scope);
    if (cue == null) return const SizedBox.shrink();
    return CaptionCueView(
      cue: cue,
      frame: frame,
      scope: scope,
      style: captions.style ?? context.fluvie.captions.defaultStyle,
      position: captions.position ?? const CaptionPosition.bottomThird(),
    );
  }
}
