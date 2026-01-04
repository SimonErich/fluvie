/// Simple Fluvie Example
///
/// This file demonstrates the simplest way to use Fluvie with the new
/// VideoPreview and VideoExporter APIs. Use this as a quick reference
/// for getting started.
///
/// To run this example:
///   1. Update main.dart to use SimpleExampleApp instead of MyApp
///   2. Run: flutter run
///
/// Or create a new project and copy this code to your main.dart.
library;

import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/declarative.dart';

/// Simple example app demonstrating VideoPreview and VideoExporter
class SimpleExampleApp extends StatelessWidget {
  const SimpleExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Fluvie Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SimpleExamplePage(),
    );
  }
}

class SimpleExamplePage extends StatelessWidget {
  const SimpleExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Simple Fluvie Example'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: VideoPreview(
        // Your Video widget goes here
        video: const HelloWorldVideo(),

        // Show playback controls (play/pause, scrubber)
        showControls: true,

        // Show export button in controls
        showExportButton: true,

        // Auto-play on load
        autoPlay: true,

        // Loop continuously
        loop: true,

        // Optional: handle export completion
        onExportComplete: (path) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video saved to: $path')),
          );
        },
      ),
    );
  }
}

/// A simple Hello World video
class HelloWorldVideo extends StatelessWidget {
  const HelloWorldVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return Video(
      fps: 30,
      width: 1080,
      height: 1920,
      defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
      scenes: [
        // Scene 1: Hello World
        Scene(
          durationInFrames: 90, // 3 seconds
          background: Background.gradient(
            colors: {
              0: const Color(0xFF667EEA),
              90: const Color(0xFF764BA2),
            },
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          children: [
            VCenter(
              child: AnimatedText.slideUpFade(
                'Hello, World!',
                startFrame: 10,
                duration: 30,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        // Scene 2: Made with Fluvie
        Scene(
          durationInFrames: 90, // 3 seconds
          background: Background.gradient(
            colors: {
              0: const Color(0xFF0EA5E9),
              90: const Color(0xFF0284C7),
            },
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          children: [
            VCenter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedProp(
                    startFrame: 5,
                    duration: 30,
                    animation: PropAnimation.combine([
                      PropAnimation.zoomIn(start: 0.5),
                      PropAnimation.fadeIn(),
                    ]),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedText.scaleFade(
                    'Made with Fluvie',
                    startFrame: 30,
                    duration: 25,
                    startScale: 0.8,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Alternative: Export video programmatically
///
/// Use this approach when you need more control over the export process.
class ProgrammaticExportExample extends StatefulWidget {
  const ProgrammaticExportExample({super.key});

  @override
  State<ProgrammaticExportExample> createState() =>
      _ProgrammaticExportExampleState();
}

class _ProgrammaticExportExampleState extends State<ProgrammaticExportExample> {
  double _progress = 0;
  bool _isExporting = false;

  Future<void> _exportVideo() async {
    setState(() {
      _isExporting = true;
      _progress = 0;
    });

    try {
      final path = await VideoExporter(const HelloWorldVideo())
          .withQuality(RenderQuality.high)
          .withFileName('hello_world.mp4')
          .withProgress((progress) {
            setState(() => _progress = progress);
          })
          .render();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programmatic Export')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isExporting) ...[
              CircularProgressIndicator(value: _progress),
              const SizedBox(height: 16),
              Text('${(_progress * 100).toInt()}%'),
            ] else
              ElevatedButton.icon(
                onPressed: _exportVideo,
                icon: const Icon(Icons.download),
                label: const Text('Export Video'),
              ),
          ],
        ),
      ),
    );
  }
}
