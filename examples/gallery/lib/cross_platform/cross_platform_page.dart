import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/cross_platform/render_on_device.dart';

/// One on-device demo that runs on mobile and web: the same `Video` with audio,
/// rendered through whichever encoder the build selects.
///
/// `flutter run -t lib/cross_platform/cross_platform_page.dart` on a device. To
/// run it on the web, wrap the app in a `FluvieWebStage` and add the
/// `FluvieFfmpeg` bridge to `web/index.html` (see the fluvie_web_encoder example).
void main() => runApp(const CrossPlatformDemoApp());

/// The app shell for the cross-platform on-device demo.
class CrossPlatformDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const CrossPlatformDemoApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'Fluvie cross-platform on-device', home: _CrossPlatformPage());
}

class _CrossPlatformPage extends StatefulWidget {
  const _CrossPlatformPage();

  @override
  State<_CrossPlatformPage> createState() => _CrossPlatformPageState();
}

class _CrossPlatformPageState extends State<_CrossPlatformPage> {
  String _status = 'Render the same Video on this platform.';
  bool _busy = false;

  Future<void> _render() async {
    setState(() {
      _busy = true;
      _status = 'Rendering on device…';
    });
    try {
      // #docregion call
      final bytes = await renderOnDevice(
        _demo(),
        onProgress: (progress) => setState(() => _status = 'Rendering (${progress.phase.name})…'),
      );
      // #enddocregion call
      setState(() => _status = 'Rendered ${bytes.length} bytes on this platform.');
    } on Object catch (error) {
      setState(() => _status = 'Failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cross-platform on-device')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _busy ? null : _render,
              child: Text(_busy ? 'Rendering…' : 'Render'),
            ),
            const SizedBox(height: 16),
            Padding(padding: const EdgeInsets.all(20), child: SelectableText(_status)),
          ],
        ),
      ),
    );
  }
}

Video _demo() => Video(
  size: VideoSize.square,
  audio: const [Audio.music('assets/audio/beat_loop.wav', loop: true)],
  scenes: [
    Scene(
      duration: 2.seconds,
      background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
      children: [
        const Text(
          'One Video, every platform',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ).animate([Animation.fadeIn()]),
      ],
    ),
  ],
);
