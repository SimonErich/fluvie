/// The preview app `fluvie init` writes to `lib/main.dart` in new projects.
///
/// `Video` has no wall-clock ticker, so the preview drives a `RenderController`
/// from a `Ticker` and offers a play/pause button and a scrub slider. It uses
/// only the public Fluvie API.
library;

/// The source of the preview `lib/main.dart`.
///
/// [importLine] imports the composition; [functionName] is the builder; [title]
/// is the window title.
String previewAppSource({
  required String importLine,
  required String functionName,
  required String title,
}) => _preview
    .replaceFirst('{{IMPORT}}', importLine)
    .replaceFirst('{{FUNCTION}}', functionName)
    .replaceFirst('{{TITLE}}', title);

const String _preview = r'''
// A live preview for your Fluvie composition. Run it with `flutter run`.
//
// `Video` is driven by a frame index, not a wall clock, so this app owns a
// `RenderController` and advances it from a `Ticker`. Drag the slider to scrub.

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
{{IMPORT}}

void main() => runApp(const FluviePreviewApp());

/// The preview app shell.
class FluviePreviewApp extends StatelessWidget {
  /// Creates the preview app.
  const FluviePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '{{TITLE}}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const VideoPreview(builder: {{FUNCTION}}),
    );
  }
}

/// Plays a [Video] in a loop with a play/pause button and a scrub slider.
class VideoPreview extends StatefulWidget {
  /// Creates a preview for the composition [builder].
  const VideoPreview({required this.builder, super.key});

  /// Builds the composition to preview.
  final Video Function() builder;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> with SingleTickerProviderStateMixin {
  late final Video _video = widget.builder();
  final RenderController _controller = RenderController();
  late final _ticker = createTicker(_onTick);
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final total = _video.totalFrames;
    final frame = ((elapsed.inMicroseconds / 1e6) * _video.fps).floor() % total;
    _controller.seek(frame);
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      _playing ? _ticker.start() : _ticker.stop();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF14141C),
                child: Center(
                  child: RenderModeContext(
                    mode: RenderMode.preview,
                    child: RenderControllerScope(
                      controller: _controller,
                      child: AspectRatio(
                        aspectRatio: _video.width / _video.height,
                        child: FittedBox(
                          child: SizedBox(
                            width: _video.width.toDouble(),
                            height: _video.height.toDouble(),
                            child: _video,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final total = _video.totalFrames;
                final frame = _controller.frame.clamp(0, total - 1);
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      onPressed: _togglePlay,
                    ),
                    Expanded(
                      child: Slider(
                        value: frame.toDouble(),
                        max: (total - 1).toDouble(),
                        onChanged: (value) {
                          if (_playing) _togglePlay();
                          _controller.seek(value.round());
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text('${frame + 1} / $total'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
''';
