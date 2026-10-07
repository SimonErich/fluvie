import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/web_clip_decoder.dart';
import 'package:fluvie/src/rendering/assets/render_fonts.dart';
import 'package:fluvie/src/rendering/runtime/live_playback_controller.dart';
import 'package:fluvie/src/rendering/runtime/live_player.dart';
import 'package:fluvie/src/rendering/runtime/preview_audio_controller.dart';
import 'package:fluvie/src/rendering/runtime/preview_media_scope.dart';

part 'video_preview_audio.dart';
part 'video_preview_controls.dart';
part 'video_preview_state.dart';

/// A fitted, prepared Flutter video preview with playback and scrubbing.
///
/// Owns its clock when [controller] is omitted. Preparation happens once per
/// composition and source frames decode on demand. [VideoPreview.builder]
/// rebuilds authored code after hot reload while retaining the current position.
final class VideoPreview extends StatefulWidget {
  /// Previews an authored Video using the same media painters as capture.
  const VideoPreview({
    required Video this.video,
    this.controller,
    this.resolver,
    this.clipDecoder,
    this.assetBundle,
    this.audio,
    this.autoplay = true,
    this.loop = false,
    this.showControls = true,
    this.maxClipEdge = 720,
    this.onError,
    this.onReady,
    this.surfaceBuilder,
    super.key,
  }) : builder = null;

  /// Calls [builder] initially and again after hot reload.
  const VideoPreview.builder({
    required Video Function() this.builder,
    this.controller,
    this.resolver,
    this.clipDecoder,
    this.assetBundle,
    this.audio,
    this.autoplay = true,
    this.loop = false,
    this.showControls = true,
    this.maxClipEdge = 720,
    this.onError,
    this.onReady,
    this.surfaceBuilder,
    super.key,
  }) : video = null;

  /// Authored composition; mutually exclusive with [builder].
  final Video? video;

  /// Hot reload aware composition factory.
  final Video Function()? builder;

  /// Optional caller-owned playback clock.
  final LivePlaybackController? controller;

  /// Optional caller-owned media resolver.
  final MediaResolver? resolver;

  /// Optional WebCodecs/native-bridge browser decoder.
  final WebClipDecoder? clipDecoder;

  /// Optional project asset overlay shared by all Flutter children.
  final AssetBundle? assetBundle;

  /// Optional caller-owned platform audio synchronized with the video clock.
  final PreviewAudioController? audio;

  /// Optional application-owned preview surface. The supplied canvas retains
  /// Fluvie's resource preparation and frame clock. Returning a custom shell
  /// bypasses the built-in Material surface and controls.
  // ignore: avoid_positional_boolean_parameters — preserve the existing surface callback signature.
  final Widget Function(BuildContext context, Widget canvas, bool ready, Object? error)?
  surfaceBuilder;

  /// Starts visual playback once preparation succeeds.
  final bool autoplay;

  /// Restarts from frame zero at the end.
  final bool loop;

  /// Shows playback, sound activation, position and scrubbing controls.
  final bool showControls;

  /// Proxy raster bound; source layout and timing are unchanged.
  final int? maxClipEdge;

  /// Reports preparation or audio failures visibly through the host.
  final ValueChanged<Object>? onError;

  /// Receives the prepared caller/preview-owned resolver.
  final ValueChanged<MediaResolver>? onReady;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}
