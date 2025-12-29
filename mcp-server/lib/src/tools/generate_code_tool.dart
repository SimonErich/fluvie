import '../mcp/mcp_types.dart';

/// Creates the generateCode tool definition
ToolDefinition createGenerateCodeTool() {
  return ToolDefinition(
    name: 'generateCode',
    description: '''Generate Fluvie code for video compositions based on a natural language description.

Can generate:
- Complete Video compositions with multiple scenes
- Individual Scene implementations
- Template usage with proper data setup
- Animation configurations using AnimatedProp, PropAnimation
- Layout structures using VStack, VColumn, VRow, VCenter, etc.

The generated code uses the declarative API: import 'package:fluvie/declarative.dart';''',
    inputSchema: {
      'type': 'object',
      'properties': {
        'description': {
          'type': 'string',
          'description':
              'Natural language description of the video you want to create (e.g., "intro scene with title animation and particle effects")',
        },
        'type': {
          'type': 'string',
          'enum': ['full_video', 'scene', 'template_usage', 'animation', 'layout'],
          'description': 'Type of code to generate',
        },
        'fps': {
          'type': 'integer',
          'default': 30,
          'description': 'Frames per second for timing calculations',
        },
        'aspectRatio': {
          'type': 'string',
          'enum': ['9:16', '16:9', '1:1', '4:3'],
          'default': '9:16',
          'description': 'Video aspect ratio',
        },
      },
      'required': ['description'],
    },
    handler: (args) async {
      final description = args['description'] as String;
      final type = args['type'] as String? ?? 'full_video';
      final fps = args['fps'] as int? ?? 30;
      final aspectRatio = args['aspectRatio'] as String? ?? '9:16';

      final code = _generateCode(
        description: description,
        type: type,
        fps: fps,
        aspectRatio: aspectRatio,
      );

      return ToolResult(
        content: [TextContent(code)],
      );
    },
  );
}

String _generateCode({
  required String description,
  required String type,
  required int fps,
  required String aspectRatio,
}) {
  final descLower = description.toLowerCase();
  final dimensions = _getDimensions(aspectRatio);

  final buffer = StringBuffer();

  buffer.writeln('# Generated Fluvie Code\n');
  buffer.writeln('Based on: "$description"\n');
  buffer.writeln('```dart');
  buffer.writeln("import 'package:flutter/material.dart';");
  buffer.writeln("import 'package:fluvie/declarative.dart';");
  buffer.writeln();

  switch (type) {
    case 'full_video':
      _generateFullVideo(buffer, descLower, fps, dimensions);
    case 'scene':
      _generateScene(buffer, descLower, fps);
    case 'template_usage':
      _generateTemplateUsage(buffer, descLower, fps, dimensions);
    case 'animation':
      _generateAnimation(buffer, descLower);
    case 'layout':
      _generateLayout(buffer, descLower);
    default:
      _generateFullVideo(buffer, descLower, fps, dimensions);
  }

  buffer.writeln('```');
  buffer.writeln();
  buffer.writeln('## Notes\n');
  buffer.writeln('- Timing is in frames. At ${fps}fps: 30 frames = 1 second');
  buffer.writeln('- Adjust `startFrame` values to control when elements appear');
  buffer.writeln('- Use `fadeInFrames`/`fadeOutFrames` for smooth transitions');
  buffer.writeln('- Replace asset paths with your actual file paths');

  return buffer.toString();
}

void _generateFullVideo(StringBuffer buffer, String desc, int fps, _Dimensions dim) {
  final hasStats = desc.contains('stat') || desc.contains('number') || desc.contains('count');
  final hasPhotos = desc.contains('photo') || desc.contains('image') || desc.contains('memor');
  final hasParticles = desc.contains('particle') || desc.contains('sparkle') || desc.contains('confetti');
  final hasIntro = desc.contains('intro') || desc.contains('title') || desc.contains('opening');
  final hasOutro = desc.contains('outro') || desc.contains('ending') || desc.contains('close');

  buffer.writeln('class MyVideo extends StatelessWidget {');
  buffer.writeln('  @override');
  buffer.writeln('  Widget build(BuildContext context) {');
  buffer.writeln('    return Video(');
  buffer.writeln('      fps: $fps,');
  buffer.writeln('      width: ${dim.width},');
  buffer.writeln('      height: ${dim.height},');
  buffer.writeln('      defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),');
  buffer.writeln('      // Uncomment to add background music:');
  buffer.writeln("      // backgroundMusicAsset: 'assets/music.mp3',");
  buffer.writeln('      // musicVolume: 0.7,');
  buffer.writeln('      scenes: [');

  if (hasIntro || !hasStats && !hasPhotos) {
    buffer.writeln('        _buildIntroScene(),');
  }
  if (hasStats) {
    buffer.writeln('        _buildStatsScene(),');
  }
  if (hasPhotos) {
    buffer.writeln('        _buildMemoriesScene(),');
  }
  if (hasOutro || hasIntro) {
    buffer.writeln('        _buildOutroScene(),');
  }

  buffer.writeln('      ],');
  buffer.writeln('    );');
  buffer.writeln('  }');
  buffer.writeln();

  // Generate intro scene
  if (hasIntro || !hasStats && !hasPhotos) {
    buffer.writeln('  Scene _buildIntroScene() {');
    buffer.writeln('    return Scene(');
    buffer.writeln('      durationInFrames: 120,');
    buffer.writeln('      background: Background.gradient(');
    buffer.writeln('        colors: {0: const Color(0xFF1a1a2e), 120: const Color(0xFF0f3460)},');
    buffer.writeln('      ),');
    buffer.writeln('      fadeInFrames: 20,');
    buffer.writeln('      children: [');
    if (hasParticles) {
      buffer.writeln('        ParticleEffect.sparkles(count: 25),');
    }
    buffer.writeln('        VCenter(');
    buffer.writeln('          child: Column(');
    buffer.writeln('            mainAxisAlignment: MainAxisAlignment.center,');
    buffer.writeln('            children: [');
    buffer.writeln('              AnimatedText.scaleFade(');
    buffer.writeln("                'YOUR TITLE',");
    buffer.writeln('                duration: 30,');
    buffer.writeln('                startScale: 0.5,');
    buffer.writeln('                style: const TextStyle(');
    buffer.writeln('                  fontSize: 80,');
    buffer.writeln('                  fontWeight: FontWeight.w900,');
    buffer.writeln('                  color: Colors.white,');
    buffer.writeln('                ),');
    buffer.writeln('              ),');
    buffer.writeln('              const SizedBox(height: 20),');
    buffer.writeln('              AnimatedText.slideUpFade(');
    buffer.writeln("                'Subtitle text',");
    buffer.writeln('                startFrame: 30,');
    buffer.writeln('                duration: 25,');
    buffer.writeln('                style: TextStyle(');
    buffer.writeln('                  fontSize: 32,');
    buffer.writeln('                  color: Colors.white.withValues(alpha: 0.8),');
    buffer.writeln('                ),');
    buffer.writeln('              ),');
    buffer.writeln('            ],');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('      ],');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  // Generate stats scene
  if (hasStats) {
    buffer.writeln('  Scene _buildStatsScene() {');
    buffer.writeln('    return Scene(');
    buffer.writeln('      durationInFrames: 180,');
    buffer.writeln('      background: Background.gradient(');
    buffer.writeln('        colors: {0: const Color(0xFF2c003e), 180: const Color(0xFF512b58)},');
    buffer.writeln('      ),');
    buffer.writeln('      children: [');
    buffer.writeln('        VPositioned(');
    buffer.writeln('          top: 200,');
    buffer.writeln('          left: 0,');
    buffer.writeln('          right: 0,');
    buffer.writeln('          child: AnimatedText.slideUpFade(');
    buffer.writeln("            'BY THE NUMBERS',");
    buffer.writeln('            duration: 25,');
    buffer.writeln('            style: const TextStyle(');
    buffer.writeln('              fontSize: 48,');
    buffer.writeln('              fontWeight: FontWeight.w900,');
    buffer.writeln('              color: Colors.white,');
    buffer.writeln('            ),');
    buffer.writeln('            textAlign: TextAlign.center,');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('        VPositioned(');
    buffer.writeln('          top: 400,');
    buffer.writeln('          left: 60,');
    buffer.writeln('          right: 60,');
    buffer.writeln('          child: Row(');
    buffer.writeln('            children: [');
    buffer.writeln('              Expanded(');
    buffer.writeln('                child: StatCard(');
    buffer.writeln('                  value: 365,');
    buffer.writeln("                  label: 'DAYS',");
    buffer.writeln('                  color: const Color(0xFFff6b6b),');
    buffer.writeln('                  startFrame: 30,');
    buffer.writeln('                ),');
    buffer.writeln('              ),');
    buffer.writeln('              const SizedBox(width: 40),');
    buffer.writeln('              Expanded(');
    buffer.writeln('                child: StatCard(');
    buffer.writeln('                  value: 1234,');
    buffer.writeln("                  label: 'ITEMS',");
    buffer.writeln('                  color: const Color(0xFF4ecdc4),');
    buffer.writeln('                  startFrame: 50,');
    buffer.writeln('                ),');
    buffer.writeln('              ),');
    buffer.writeln('            ],');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('      ],');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  // Generate memories scene
  if (hasPhotos) {
    buffer.writeln('  Scene _buildMemoriesScene() {');
    buffer.writeln('    return Scene(');
    buffer.writeln('      durationInFrames: 180,');
    buffer.writeln('      background: Background.gradient(');
    buffer.writeln('        colors: {0: const Color(0xFFff9a9e), 180: const Color(0xFFfcb69f)},');
    buffer.writeln('      ),');
    buffer.writeln('      children: [');
    buffer.writeln('        VPositioned(');
    buffer.writeln('          top: 150,');
    buffer.writeln('          left: 0,');
    buffer.writeln('          right: 0,');
    buffer.writeln('          child: AnimatedText.slideUpFade(');
    buffer.writeln("            'YOUR MEMORIES',");
    buffer.writeln('            duration: 25,');
    buffer.writeln('            style: const TextStyle(');
    buffer.writeln('              fontSize: 56,');
    buffer.writeln('              fontWeight: FontWeight.w900,');
    buffer.writeln('              color: Color(0xFF2d3436),');
    buffer.writeln('            ),');
    buffer.writeln('            textAlign: TextAlign.center,');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('        FloatingElement(');
    buffer.writeln('          position: const Offset(100, 400),');
    buffer.writeln('          floatAmplitude: const Offset(0, 10),');
    buffer.writeln('          child: PolaroidFrame(');
    buffer.writeln('            rotation: -0.08,');
    buffer.writeln("            caption: 'Memory 1',");
    buffer.writeln('            child: Image.asset(');
    buffer.writeln("              'assets/photo1.jpg',");
    buffer.writeln('              width: 280,');
    buffer.writeln('              height: 220,');
    buffer.writeln('              fit: BoxFit.cover,');
    buffer.writeln('            ),');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('        FloatingElement(');
    buffer.writeln('          position: const Offset(500, 550),');
    buffer.writeln('          floatAmplitude: const Offset(0, 10),');
    buffer.writeln('          floatPhase: 45,');
    buffer.writeln('          child: PolaroidFrame(');
    buffer.writeln('            rotation: 0.06,');
    buffer.writeln("            caption: 'Memory 2',");
    buffer.writeln('            child: Image.asset(');
    buffer.writeln("              'assets/photo2.jpg',");
    buffer.writeln('              width: 280,');
    buffer.writeln('              height: 220,');
    buffer.writeln('              fit: BoxFit.cover,');
    buffer.writeln('            ),');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('      ],');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();
  }

  // Generate outro scene
  if (hasOutro || hasIntro) {
    buffer.writeln('  Scene _buildOutroScene() {');
    buffer.writeln('    return Scene(');
    buffer.writeln('      durationInFrames: 150,');
    buffer.writeln('      background: Background.gradient(');
    buffer.writeln('        colors: {0: const Color(0xFF1a1a2e), 150: const Color(0xFFe94560)},');
    buffer.writeln('      ),');
    buffer.writeln('      children: [');
    if (hasParticles) {
      buffer.writeln('        ParticleEffect.sparkles(count: 40, color: const Color(0xFFe94560)),');
    }
    buffer.writeln('        VCenter(');
    buffer.writeln('          child: Column(');
    buffer.writeln('            mainAxisAlignment: MainAxisAlignment.center,');
    buffer.writeln('            children: [');
    buffer.writeln('              AnimatedText.fadeIn(');
    buffer.writeln("                'SEE YOU NEXT TIME',");
    buffer.writeln('                duration: 25,');
    buffer.writeln('                style: TextStyle(');
    buffer.writeln('                  fontSize: 40,');
    buffer.writeln('                  color: Colors.white.withValues(alpha: 0.8),');
    buffer.writeln('                  letterSpacing: 8,');
    buffer.writeln('                ),');
    buffer.writeln('              ),');
    buffer.writeln('              const SizedBox(height: 20),');
    buffer.writeln('              AnimatedText.scaleFade(');
    buffer.writeln("                'THANKS!',");
    buffer.writeln('                startFrame: 30,');
    buffer.writeln('                duration: 35,');
    buffer.writeln('                startScale: 0.5,');
    buffer.writeln('                style: const TextStyle(');
    buffer.writeln('                  fontSize: 100,');
    buffer.writeln('                  fontWeight: FontWeight.w900,');
    buffer.writeln('                  color: Color(0xFFe94560),');
    buffer.writeln('                ),');
    buffer.writeln('              ),');
    buffer.writeln('            ],');
    buffer.writeln('          ),');
    buffer.writeln('        ),');
    buffer.writeln('      ],');
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  buffer.writeln('}');
}

void _generateScene(StringBuffer buffer, String desc, int fps) {
  final hasParticles = desc.contains('particle') || desc.contains('sparkle');

  buffer.writeln('Scene buildScene() {');
  buffer.writeln('  return Scene(');
  buffer.writeln('    durationInFrames: 120, // 4 seconds at 30fps');
  buffer.writeln('    background: Background.gradient(');
  buffer.writeln('      colors: {');
  buffer.writeln('        0: const Color(0xFF1a1a2e),');
  buffer.writeln('        120: const Color(0xFF0f3460),');
  buffer.writeln('      },');
  buffer.writeln('    ),');
  buffer.writeln('    fadeInFrames: 20,');
  buffer.writeln('    fadeOutFrames: 15,');
  buffer.writeln('    children: [');
  if (hasParticles) {
    buffer.writeln('      ParticleEffect.sparkles(count: 25),');
  }
  buffer.writeln('      VCenter(');
  buffer.writeln('        child: AnimatedText.slideUpFade(');
  buffer.writeln("          'Your Content Here',");
  buffer.writeln('          duration: 30,');
  buffer.writeln('          style: const TextStyle(');
  buffer.writeln('            fontSize: 64,');
  buffer.writeln('            fontWeight: FontWeight.bold,');
  buffer.writeln('            color: Colors.white,');
  buffer.writeln('          ),');
  buffer.writeln('        ),');
  buffer.writeln('      ),');
  buffer.writeln('    ],');
  buffer.writeln('  );');
  buffer.writeln('}');
}

void _generateTemplateUsage(StringBuffer buffer, String desc, int fps, _Dimensions dim) {
  String templateName = 'TheNeonGate';
  String dataType = 'IntroData';
  String category = 'intro';

  if (desc.contains('rank') || desc.contains('top')) {
    templateName = 'StackClimb';
    dataType = 'RankingData';
    category = 'ranking';
  } else if (desc.contains('stat') || desc.contains('metric')) {
    templateName = 'OrbitalMetrics';
    dataType = 'MetricsData';
    category = 'data_viz';
  } else if (desc.contains('photo') || desc.contains('collage')) {
    templateName = 'TheGridShuffle';
    dataType = 'CollageData';
    category = 'collage';
  } else if (desc.contains('outro') || desc.contains('end')) {
    templateName = 'ParticleFarewell';
    dataType = 'SummaryData';
    category = 'conclusion';
  }

  buffer.writeln('// Using the $templateName template ($category)');
  buffer.writeln();
  buffer.writeln('Video(');
  buffer.writeln('  fps: $fps,');
  buffer.writeln('  width: ${dim.width},');
  buffer.writeln('  height: ${dim.height},');
  buffer.writeln('  scenes: [');
  buffer.writeln('    $templateName(');
  buffer.writeln('      data: $dataType(');

  switch (dataType) {
    case 'IntroData':
      buffer.writeln("        title: 'Your 2024',");
      buffer.writeln("        subtitle: 'Wrapped',");
      buffer.writeln('        year: 2024,');
    case 'RankingData':
      buffer.writeln("        title: 'Top 5',");
      buffer.writeln('        items: [');
      buffer.writeln("          RankingItem(rank: 1, title: 'First', subtitle: 'Details'),");
      buffer.writeln("          RankingItem(rank: 2, title: 'Second', subtitle: 'Details'),");
      buffer.writeln("          RankingItem(rank: 3, title: 'Third', subtitle: 'Details'),");
      buffer.writeln('        ],');
    case 'MetricsData':
      buffer.writeln("        title: 'Your Stats',");
      buffer.writeln('        metrics: [');
      buffer.writeln("          Metric(label: 'Hours', value: 1234),");
      buffer.writeln("          Metric(label: 'Items', value: 567),");
      buffer.writeln('        ],');
    case 'CollageData':
      buffer.writeln("        title: 'Memories',");
      buffer.writeln("        images: ['assets/1.jpg', 'assets/2.jpg', 'assets/3.jpg'],");
    case 'SummaryData':
      buffer.writeln("        message: 'See you next year!',");
      buffer.writeln('        year: 2024,');
  }

  buffer.writeln('      ),');
  buffer.writeln('    ).toScene(),');
  buffer.writeln('  ],');
  buffer.writeln(')');
}

void _generateAnimation(StringBuffer buffer, String desc) {
  buffer.writeln('// Animation example based on: "$desc"');
  buffer.writeln();
  buffer.writeln('// Option 1: Using AnimatedProp');
  buffer.writeln('AnimatedProp(');
  buffer.writeln('  animation: PropAnimation.combine([');
  buffer.writeln('    PropAnimation.slideUp(distance: 50),');
  buffer.writeln('    PropAnimation.fadeIn(),');
  buffer.writeln('  ]),');
  buffer.writeln('  duration: 30,');
  buffer.writeln('  startFrame: 0,');
  buffer.writeln('  curve: Curves.easeOutCubic,');
  buffer.writeln('  child: YourWidget(),');
  buffer.writeln(')');
  buffer.writeln();
  buffer.writeln('// Option 2: Using AnimatedText');
  buffer.writeln('AnimatedText.slideUpFade(');
  buffer.writeln("  'Your Text',");
  buffer.writeln('  duration: 30,');
  buffer.writeln('  startFrame: 0,');
  buffer.writeln('  style: const TextStyle(fontSize: 48),');
  buffer.writeln(')');
  buffer.writeln();
  buffer.writeln('// Option 3: Using TimeConsumer for custom animation');
  buffer.writeln('TimeConsumer(');
  buffer.writeln('  builder: (context, frame, progress) {');
  buffer.writeln('    final opacity = interpolate(frame, [0, 30], [0.0, 1.0]);');
  buffer.writeln('    final scale = interpolate(frame, [0, 30], [0.8, 1.0]);');
  buffer.writeln('    return Transform.scale(');
  buffer.writeln('      scale: scale,');
  buffer.writeln('      child: Opacity(opacity: opacity, child: YourWidget()),');
  buffer.writeln('    );');
  buffer.writeln('  },');
  buffer.writeln(')');
}

void _generateLayout(StringBuffer buffer, String desc) {
  buffer.writeln('// Layout example based on: "$desc"');
  buffer.writeln();
  buffer.writeln('// Vertical layout with stagger animation');
  buffer.writeln('VColumn(');
  buffer.writeln('  spacing: 20,');
  buffer.writeln('  stagger: StaggerConfig.slideUp(delay: 10, duration: 30),');
  buffer.writeln('  children: [');
  buffer.writeln("    Text('Item 1'),");
  buffer.writeln("    Text('Item 2'),");
  buffer.writeln("    Text('Item 3'),");
  buffer.writeln('  ],');
  buffer.writeln(')');
  buffer.writeln();
  buffer.writeln('// Positioned elements with timing');
  buffer.writeln('LayerStack(');
  buffer.writeln('  children: [');
  buffer.writeln('    Layer.background(child: Background.solid(Colors.black)),');
  buffer.writeln('    Layer(');
  buffer.writeln('      startFrame: 30,');
  buffer.writeln('      fadeInFrames: 15,');
  buffer.writeln('      child: VPositioned(');
  buffer.writeln('        top: 100,');
  buffer.writeln('        left: 50,');
  buffer.writeln('        right: 50,');
  buffer.writeln('        child: YourContent(),');
  buffer.writeln('      ),');
  buffer.writeln('    ),');
  buffer.writeln('  ],');
  buffer.writeln(')');
}

_Dimensions _getDimensions(String aspectRatio) {
  switch (aspectRatio) {
    case '9:16':
      return const _Dimensions(1080, 1920);
    case '16:9':
      return const _Dimensions(1920, 1080);
    case '1:1':
      return const _Dimensions(1080, 1080);
    case '4:3':
      return const _Dimensions(1440, 1080);
    default:
      return const _Dimensions(1080, 1920);
  }
}

class _Dimensions {
  final int width;
  final int height;

  const _Dimensions(this.width, this.height);
}
