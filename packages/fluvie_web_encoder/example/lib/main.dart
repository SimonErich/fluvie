import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

// Wrap the app once in a FluvieWebStage: it gives in-browser rendering an
// off-screen capture surface inside the app's own pipeline. Nothing else is
// needed; WebVideoRenderer().render(...) captures through it by default.
// #docregion stage
void main() => runApp(const FluvieWebStage(child: WebEncoderExampleApp()));
// #enddocregion stage

/// Renders a Fluvie [Video] to an MP4 in the browser on first frame and shows
/// the result. Doubles as the end-to-end headless-Chrome verification: it prints
/// `FLUVIE_E2E_RESULT ok bytes=<n> ftyp=<box>` to the console on success.
class WebEncoderExampleApp extends StatefulWidget {
  /// Creates the example app.
  const WebEncoderExampleApp({super.key});

  @override
  State<WebEncoderExampleApp> createState() => _WebEncoderExampleAppState();
}

class _WebEncoderExampleAppState extends State<WebEncoderExampleApp> {
  String _status = 'Rendering in the browser…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _render());
  }

  Future<void> _render() async {
    try {
      // #docregion render
      final bytes = await WebVideoRenderer().render(
        composition: _demoVideo(),
        aspect: Aspect.square,
        duration: const Duration(seconds: 2),
        longEdge: 480,
        audio: true, // mix the bundled music bed into the MP4, in the browser
      );
      // The MP4 never left the browser; deliver `bytes` as a download or upload.
      // #enddocregion render
      final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
      _set('FLUVIE_E2E_RESULT ok bytes=${bytes.length} ftyp=$ftyp');
    } on Object catch (error, stack) {
      _set('FLUVIE_E2E_ERROR $error');
      debugPrint('$error\n$stack');
    }
  }

  void _set(String status) {
    // The end-to-end harness reads this marker line from the browser console.
    // ignore: avoid_print
    print(status);
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fluvie_web_encoder',
      home: Scaffold(body: Center(child: SelectableText(_status))),
    );
  }
}

Video _demoVideo() => Video(
  size: VideoSize.square,
  audio: const [Audio.music('assets/audio/beat_loop.wav', loop: true)],
  scenes: [
    Scene(
      duration: 1.seconds,
      background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
      children: [
        const Text(
          'Web!',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ).animate([Animation.fadeIn()]),
      ],
    ),
  ],
);
