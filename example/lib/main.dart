import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluvie Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  final _boundaryKey = GlobalKey();
  bool _isRendering = false;
  String? _outputPath;
  int _currentFrame = 0;

  Future<void> _renderVideo() async {
    setState(() {
      _isRendering = true;
      _outputPath = null;
    });

    try {
      final renderService = ref.read(renderServiceProvider);
      
      final config = RenderConfig(
        timeline: TimelineConfig(
          fps: 30,
          durationInFrames: 90, // 3 seconds
          width: 1080,
          height: 1080,
        ),
        clips: [],
      );

      final path = await renderService.execute(
        config: config,
        repaintBoundaryKey: _boundaryKey,
        onFrameUpdate: (frame) {
          setState(() {
            _currentFrame = frame;
          });
        },
      );

      if (mounted) {
        setState(() {
          _outputPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRendering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fluvie Generator'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: FrameProvider(
                    frame: _currentFrame,
                    child: VideoComposition(
                      fps: 30,
                      durationInFrames: 90,
                      width: 1080,
                      height: 1080,
                      child: Container(
                        width: 300, // Scaled down for preview
                        height: 300,
                        color: Colors.white,
                        child: Stack(
                          children: [
                            // Background
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue, Colors.purple],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                            ),
                            // Animated Circle
                            TimeConsumer(
                              builder: (context, frame, progress) {
                                return Positioned(
                                  left: 20 + (progress * 200),
                                  top: 100,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Text
                            TimeConsumer(
                              builder: (context, frame, progress) {
                                return Center(
                                  child: Opacity(
                                    opacity: progress,
                                    child: const Text(
                                      'Hello Fluvie!',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isRendering)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Rendering frame: $_currentFrame / 90'),
                ],
              ),
            ),
          if (_outputPath != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Video saved to:\n$_outputPath', textAlign: TextAlign.center),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isRendering ? null : _renderVideo,
              child: const Text('Render Video'),
            ),
          ),
        ],
      ),
    );
  }
}
