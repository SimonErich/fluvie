// #docregion render-request
import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/rendering.dart' show RenderCancellation, VideoRenderRequest;

/// Request two authored seconds, starting four seconds into a composition.
VideoRenderRequest excerptRequest(Widget composition, RenderCancellation cancellation) =>
    VideoRenderRequest(
      composition: composition,
      width: 480,
      height: 270,
      startFrame: 120,
      frameCount: 60,
      posterFrame: 15,
      cancellation: cancellation,
    );
// #enddocregion render-request
