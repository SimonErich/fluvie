import 'package:flutter/material.dart' hide Animation;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/10_audio_and_captions.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

/// A standalone entry so this page runs on its own:
/// `flutter run -t lib/on_device/on_device_page.dart` on a device or simulator.
void main() => runApp(const OnDeviceDemoApp());

/// The app shell for the on-device rendering demo.
class OnDeviceDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const OnDeviceDemoApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'Fluvie on-device rendering', home: OnDeviceRenderPage());
}

/// Renders a Fluvie video to an MP4 on the device and reports where it landed.
///
/// The same `Video` you would render on a desktop renders here through the
/// platform's hardware encoder, with nothing leaving the phone. This page also
/// spells out the trade-offs (see [_points]).
class OnDeviceRenderPage extends StatefulWidget {
  /// Creates the demo page.
  const OnDeviceRenderPage({super.key});

  @override
  State<OnDeviceRenderPage> createState() => _OnDeviceRenderPageState();
}

class _OnDeviceRenderPageState extends State<OnDeviceRenderPage> {
  String _status = 'Press render to encode lesson 10 on the device.';
  bool _busy = false;
  bool _withAudio = true;

  Future<void> _render() async {
    setState(() {
      _busy = true;
      _status = 'Capturing…';
    });
    try {
      // #docregion render
      final renderer = OnDeviceVideoRenderer();
      final file = await renderer.render(
        composition: lesson10Video(),
        aspect: Aspect.landscape,
        duration: const Duration(seconds: 4),
        longEdge: 480,
        audio: _withAudio, // mix and mux the lesson's music bed on the device
        onProgress: (progress) => debugPrint('on-device render: ${progress.phase.name}'),
      );
      // #enddocregion render
      _set('Wrote ${file.path}');
    } on FluvieMobileEncoderException catch (error) {
      _set('Failed (${error.code ?? 'error'}): ${error.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _set(String status) {
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On-device rendering')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final point in _points) _PointTile(point),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Encode audio'),
            subtitle: const Text("Mix the lesson's music bed into the MP4"),
            value: _withAudio,
            onChanged: _busy ? null : (value) => setState(() => _withAudio = value),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _render,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(_busy ? 'Rendering…' : 'Render on device'),
          ),
          const SizedBox(height: 16),
          SelectableText(_status),
        ],
      ),
    );
  }
}

/// One explanation point shown on the page.
typedef _Point = ({String title, String body});

const List<_Point> _points = [
  (
    title: 'How it works',
    body:
        'Fluvie captures the widget tree to raw frames off-screen, then the '
        'platform hardware encoder (MediaCodec on Android, AVAssetWriter on iOS) '
        'writes the MP4. No FFmpeg, no server, no network.',
  ),
  (
    title: 'The advantage',
    body:
        'The frames never leave the device, so generation is private by '
        'construction, and there is no render bill and no upload wait.',
  ),
  (
    title: 'Audio is opt-in',
    body:
        'Declare Audio on your Video as usual and pass audio: true to mix and mux '
        'it natively; leave it off and a Video with audio renders silent with a '
        'one-time warning. The default flow never changes for anyone.',
  ),
  (
    title: 'The trade-offs',
    body:
        'MP4 only, and the encoded file is per-device because hardware encoders '
        'are not bit-exact. The captured frames stay byte-identical everywhere.',
  ),
];

class _PointTile extends StatelessWidget {
  const _PointTile(this.point);

  final _Point point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(point.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(point.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
