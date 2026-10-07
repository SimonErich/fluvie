// #docregion composition-video
import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie/rendering.dart' show compositionVideo;

/// Inspect a declared Video under transparent single-child wrappers.
Video? findAuthoredVideo(Widget composition) => compositionVideo(composition);
// #enddocregion composition-video
