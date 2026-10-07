import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show LivePlaybackController;
import 'package:fluvie_editor/src/colour/colour_scopes.dart';

/// Read-back around the existing settled stage, inside its warmed scopes and
/// before editor selection/handles. Never builds a second rendering path.
final class ScopePreview extends StatefulWidget {
  /// Samples the existing child under the supplied frame clock.
  const ScopePreview({
    required this.controller,
    required this.clock,
    required this.digest,
    required this.child,
    super.key,
  });

  /// Receives coalesced, settled preview requests.
  final ColourScopesController controller;

  /// The exact clock driving the visible composition.
  final LivePlaybackController clock;

  /// The render identity, including the preview’s scene or video scope.
  final String digest;

  /// The existing preview tree, without editor selection handles.
  final Widget child;
  @override
  State<ScopePreview> createState() => _ScopePreviewState();
}

final class _ScopePreviewState extends State<ScopePreview> {
  final GlobalKey<State<StatefulWidget>> _boundary = GlobalKey();
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    widget.clock.frames.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(ScopePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clock != oldWidget.clock) {
      oldWidget.clock.frames.removeListener(_schedule);
      widget.clock.frames.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final frame = widget.clock.frame;
      final digest = widget.digest;
      widget.controller.request('$digest:$frame', () async {
        if (!mounted || widget.clock.frame != frame || widget.digest != digest) {
          throw const StaleScopeFrame();
        }
        final boundary = _boundary.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
          throw const StaleScopeFrame();
        }
        final result = await ColourScopesController.capture(boundary);
        if (!mounted || widget.clock.frame != frame || widget.digest != digest) {
          throw const StaleScopeFrame();
        }
        return result;
      });
    });
  }

  @override
  void dispose() {
    widget.clock.frames.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _boundary, child: widget.child);
}
