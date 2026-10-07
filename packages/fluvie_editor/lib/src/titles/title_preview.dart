import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_editor/src/titles/title_catalog.dart';

/// A still of the exact bundled composition, without mutating an open document.
final class TitlePreview extends StatefulWidget {
  /// Previews the title at its settled frame in a compact browser card.
  const TitlePreview({required this.title, super.key});

  /// The data-authored composition to render.
  final TitleTemplate title;
  @override
  State<TitlePreview> createState() => _TitlePreviewState();
}

final class _TitlePreviewState extends State<TitlePreview> {
  final RenderController _controller = RenderController(initialFrame: 100);
  late final Video _video = VideoSpec.fromJson({
    'fluvieSpec': 1,
    'size': {'width': 640, 'height': 360},
    'fps': 30,
    'theme': widget.title.json['theme'],
    'scenes': [
      {'duration': '120f', 'children': widget.title.json['children']},
    ],
  }).build();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRect(
          child: FittedBox(
            child: SizedBox(
              width: 640,
              height: 360,
              child: RenderControllerScope(controller: _controller, child: _video),
            ),
          ),
        ),
      ),
    ),
  );
}
