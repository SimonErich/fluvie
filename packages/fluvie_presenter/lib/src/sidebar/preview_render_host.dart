import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show Video;
import 'package:fluvie_presenter/src/sidebar/slide_preview_frame.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';

/// The hidden stage previews render on: one requested slide at a time,
/// mounted at thumbnail size behind the opaque stage (painted, never seen),
/// captured through its repaint boundary, then unmounted.
///
/// The shell mounts one of these underneath the stage and binds the preview
/// service's renderer to [PreviewRenderHostState.render]. Requests serialize
/// here — one live composition at a time keeps the host cheap — while the
/// service above owns queueing and caching.
final class PreviewRenderHost extends StatefulWidget {
  /// Creates the host for [video]'s compiled [plans].
  const PreviewRenderHost({
    required this.video,
    required this.plans,
    this.thumbWidth = 320,
    super.key,
  });

  /// The authored deck.
  final Video video;

  /// The compiled deck, one plan per slide.
  final List<SlidePlan> plans;

  /// The rendered preview width in logical pixels; height follows the
  /// canvas aspect.
  final double thumbWidth;

  @override
  State<PreviewRenderHost> createState() => PreviewRenderHostState();
}

/// The host's rendering surface — public so the shell can bind the preview
/// service's renderer to [render].
final class PreviewRenderHostState extends State<PreviewRenderHost> {
  final GlobalKey _boundary = GlobalKey();
  Future<void> _serial = Future.value();
  int? _request;

  double get _thumbHeight => widget.thumbWidth * widget.video.height / widget.video.width;

  /// Renders [slide]'s settled final state to an image. Calls serialize:
  /// the host shows one composition at a time.
  Future<ui.Image> render(int slide) {
    final result = _serial.then((_) => _renderNow(slide));
    _serial = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ui.Image> _renderNow(int slide) async {
    setState(() => _request = slide);
    // Three frames: mount and collect, resolve post-frame, paint settled.
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    if (mounted) setState(() => _request = null);
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    if (request == null) return const SizedBox.shrink();
    return SizedBox(
      width: widget.thumbWidth,
      height: _thumbHeight,
      child: RepaintBoundary(
        key: _boundary,
        child: SlidePreviewFrame(video: widget.video, plan: widget.plans[request]),
      ),
    );
  }
}
