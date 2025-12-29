import '../indexing/template_index.dart';
import '../mcp/mcp_types.dart';

/// Creates the getTemplate tool definition
ToolDefinition createGetTemplateTool() {
  return ToolDefinition(
    name: 'getTemplate',
    description: '''Get detailed information about a specific Fluvie template including its properties, data requirements, usage examples, and recommended configurations.

Available categories: intro, ranking, data_viz, collage, thematic, conclusion

Intro templates: TheNeonGate, DigitalMirror, TheMixtape, VortexTitle, NoiseID
Ranking templates: StackClimb, SlotMachine, TheSpotlight, PerspectiveLadder, FloatingPolaroids
DataViz templates: OrbitalMetrics, TheGrowthTree, LiquidMinutes, FrequencyGlow, BinaryRain
Collage templates: TheGridShuffle, SplitPersonality, MosaicReveal, BentoRecap, TriptychScroll
Thematic templates: LofiWindow, GlitchReality, RetroPostcard, Kaleidoscope, MinimalistBeat
Conclusion templates: ParticleFarewell, TheSignature, TheSummaryPoster, TheInfinityLoop, WrappedReceipt''',
    inputSchema: {
      'type': 'object',
      'properties': {
        'category': {
          'type': 'string',
          'enum': ['intro', 'ranking', 'data_viz', 'collage', 'thematic', 'conclusion'],
          'description': 'Template category',
        },
        'name': {
          'type': 'string',
          'description': 'Template name (e.g., "TheNeonGate", "StackClimb")',
        },
      },
      'required': ['category', 'name'],
    },
    handler: (args) async {
      final category = args['category'] as String;
      final name = args['name'] as String;

      final templateIndex = TemplateIndex.instance;
      final template = await templateIndex.getTemplate(category, name);

      if (template == null) {
        // Try to find by name only
        final allTemplates = templateIndex.getAllTemplates();
        final found = allTemplates.where(
          (t) => t.name.toLowerCase() == name.toLowerCase(),
        );

        if (found.isNotEmpty) {
          final correct = found.first;
          return ToolResult(
            content: [
              TextContent(
                'Template "$name" not found in category "$category".\n'
                'Did you mean: ${correct.name} (category: ${correct.category})?',
              ),
            ],
            isError: true,
          );
        }

        return ToolResult(
          content: [
            TextContent(
              'Template not found: $name in category $category.\n\n'
              'Available templates in $category:\n${templateIndex.getTemplatesByCategory(category).map((t) => "- ${t.name}").join("\n")}',
            ),
          ],
          isError: true,
        );
      }

      return ToolResult(
        content: [TextContent(_formatTemplateDetails(template))],
      );
    },
  );
}

String _formatTemplateDetails(TemplateInfo template) {
  final buffer = StringBuffer();

  buffer.writeln('# ${template.name}');
  buffer.writeln();
  buffer.writeln('**Category:** ${template.category}');
  buffer.writeln('**Recommended Length:** ${template.recommendedLength} frames');
  buffer.writeln('**Default Theme:** ${template.defaultTheme}');
  buffer.writeln('**Default Timing:** ${template.defaultTiming}');
  buffer.writeln();
  buffer.writeln('## Description');
  buffer.writeln(template.description);
  buffer.writeln();

  buffer.writeln('## Data Requirements');
  buffer.writeln('**Data Type:** `${template.dataType}`');
  buffer.writeln();
  buffer.writeln('**Required Fields:**');
  for (final field in template.requiredFields) {
    buffer.writeln('- `$field`');
  }
  buffer.writeln();
  if (template.optionalFields.isNotEmpty) {
    buffer.writeln('**Optional Fields:**');
    for (final field in template.optionalFields) {
      buffer.writeln('- `$field`');
    }
    buffer.writeln();
  }

  if (template.properties.isNotEmpty) {
    buffer.writeln('## Template Properties');
    for (final entry in template.properties.entries) {
      final prop = entry.value;
      buffer.writeln(
        '- `${entry.key}` (${prop['type']}): ${prop['description']} (default: ${prop['default']})',
      );
    }
    buffer.writeln();
  }

  buffer.writeln('## Usage Example');
  buffer.writeln();
  buffer.writeln('```dart');
  buffer.writeln("import 'package:fluvie/declarative.dart';");
  buffer.writeln();
  buffer.writeln('Video(');
  buffer.writeln('  fps: 30,');
  buffer.writeln('  width: 1080,');
  buffer.writeln('  height: 1920,');
  buffer.writeln('  scenes: [');
  buffer.writeln('    ${template.name}(');
  buffer.writeln('      data: ${template.dataType}(');

  // Generate example data based on data type
  switch (template.dataType) {
    case 'IntroData':
      buffer.writeln("        title: 'Your 2024',");
      if (template.optionalFields.contains('subtitle')) {
        buffer.writeln("        subtitle: 'Wrapped',");
      }
      if (template.optionalFields.contains('year')) {
        buffer.writeln('        year: 2024,');
      }
    case 'RankingData':
      buffer.writeln("        title: 'Top 5',");
      buffer.writeln('        items: [');
      buffer.writeln("          RankingItem(rank: 1, title: 'First Place', subtitle: 'Details'),");
      buffer.writeln("          RankingItem(rank: 2, title: 'Second Place', subtitle: 'Details'),");
      buffer.writeln("          RankingItem(rank: 3, title: 'Third Place', subtitle: 'Details'),");
      buffer.writeln('        ],');
    case 'MetricsData':
      buffer.writeln("        title: 'Your Stats',");
      buffer.writeln('        metrics: [');
      buffer.writeln("          Metric(label: 'Hours', value: 1234),");
      buffer.writeln("          Metric(label: 'Items', value: 567),");
      buffer.writeln('        ],');
    case 'CollageData':
      buffer.writeln("        title: 'Memories',");
      buffer.writeln('        images: [');
      buffer.writeln("          'assets/photo1.jpg',");
      buffer.writeln("          'assets/photo2.jpg',");
      buffer.writeln("          'assets/photo3.jpg',");
      buffer.writeln('        ],');
    case 'ThematicData':
      buffer.writeln("        text: 'Your journey continues...',");
      buffer.writeln("        mood: 'chill',");
    case 'SummaryData':
      buffer.writeln("        message: 'See you next year!',");
      buffer.writeln('        year: 2024,');
      if (template.optionalFields.contains('stats')) {
        buffer.writeln("        stats: {'songs': 1000, 'artists': 50},");
      }
    default:
      for (final field in template.requiredFields) {
        buffer.writeln("        $field: 'value',");
      }
  }

  buffer.writeln('      ),');
  if (template.defaultTheme != 'spotify') {
    buffer.writeln('      theme: TemplateTheme.${template.defaultTheme}(),');
  }
  buffer.writeln('    ).toScene(),');
  buffer.writeln('  ],');
  buffer.writeln(')');
  buffer.writeln('```');

  return buffer.toString();
}
