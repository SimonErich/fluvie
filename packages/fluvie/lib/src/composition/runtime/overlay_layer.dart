import 'package:flutter/widgets.dart';

/// The layer holding a video's overlays: the elements that belong to no scene.
///
/// A plain stack of the widgets it is given, mounted once for the whole video.
/// It deliberately does nothing else — no time scope of its own, no gating, no
/// clipping — because the point of an overlay is that it sits in the *video's*
/// scope: the layer is mounted inside it, so an overlay's `.show(...)` window
/// resolves against the video's own length and one instance spans every cut.
///
/// Overlays paint in declaration order, last on top, and lay out exactly as a
/// scene's children do: loose constraints, centred. An element moved from a
/// scene into the overlays keeps its size and its place.
final class OverlayLayer extends StatelessWidget {
  /// Mounts [overlays], first painted first.
  const OverlayLayer({required this.overlays, super.key});

  /// The elements outside every scene, in paint order.
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => Stack(
    // Exactly what `Scene.build` does with its children: centre them under
    // loose constraints. Forwarding the canvas-tight constraints instead
    // would stretch every overlay to the full frame and pin it top-left, so
    // moving an element from a scene into the overlays would silently change
    // where it is and how big it is.
    alignment: Alignment.center,
    children: overlays,
  );
}
