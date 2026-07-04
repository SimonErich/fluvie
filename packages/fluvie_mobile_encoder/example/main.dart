/// Renders a two-second clip fully on-device, no FFmpeg and no server.
///
/// Runs on Android and iOS: Fluvie's own pipeline captures the frames and the
/// platform's native encoder writes the MP4, so the video never leaves the
/// device. For a complete app on this path, see the repository's
/// `examples/mobile_purrfect`.
library;

import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() => runApp(const MaterialApp(home: _RenderPage()));

class _RenderPage extends StatefulWidget {
  const _RenderPage();

  @override
  State<_RenderPage> createState() => _RenderPageState();
}

class _RenderPageState extends State<_RenderPage> {
  String _status = 'Tap to render on-device';

  Future<void> _render() async {
    setState(() => _status = 'Rendering…');
    final file = await OnDeviceVideoRenderer().render(
      composition: Video(
        size: VideoSize.square,
        scenes: [
          Scene(
            duration: 2.seconds,
            background: Background.color(const Color(0xFF1A2980)),
            children: [
              const Text(
                'On-device',
                style: TextStyle(color: Colors.white, fontSize: 64),
              ).animate([Animation.fadeIn()]),
            ],
          ),
        ],
      ),
      aspect: Aspect.square,
      duration: const Duration(seconds: 2),
    );
    setState(() => _status = 'Saved ${file.path}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(onPressed: _render, child: Text(_status)),
      ),
    );
  }
}
