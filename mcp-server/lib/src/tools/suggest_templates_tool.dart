import '../indexing/template_index.dart';
import '../mcp/mcp_types.dart';

/// Creates the suggestTemplates tool definition
ToolDefinition createSuggestTemplatesTool() {
  return ToolDefinition(
    name: 'suggestTemplates',
    description:
        '''Suggest appropriate Fluvie templates based on your use case or content type.

Use cases include:
- Spotify Wrapped-style year reviews
- Social media content (TikTok, Instagram Stories)
- Data presentation videos
- Photo galleries and memories
- Brand intros and outros
- Statistics and achievement displays
- Rankings and top lists''',
    inputSchema: {
      'type': 'object',
      'properties': {
        'useCase': {
          'type': 'string',
          'description':
              'Describe what kind of video you want to create (e.g., "year in review with stats and photos", "top 5 songs list", "photo memories slideshow")',
        },
        'contentType': {
          'type': 'string',
          'enum': [
            'year_review',
            'statistics',
            'photo_gallery',
            'brand_intro',
            'social_content',
            'achievement',
            'ranking_list',
          ],
          'description': 'Type of content to display (optional)',
        },
        'mood': {
          'type': 'string',
          'enum': [
            'energetic',
            'nostalgic',
            'professional',
            'playful',
            'dramatic',
            'minimal',
          ],
          'description': 'Desired mood/atmosphere (optional)',
        },
      },
      'required': ['useCase'],
    },
    handler: (args) async {
      final useCase = args['useCase'] as String;
      final contentType = args['contentType'] as String?;
      final mood = args['mood'] as String?;

      final suggestions = _suggestTemplates(
        useCase: useCase,
        contentType: contentType,
        mood: mood,
      );

      if (suggestions.isEmpty) {
        return ToolResult(
          content: [
            TextContent(
              'No specific template recommendations for "$useCase".\n\n'
              'Try describing your video content more specifically, or explore '
              'all templates using the getTemplate tool with different categories:\n'
              '- intro: Opening sequences\n'
              '- ranking: Top lists and winner reveals\n'
              '- data_viz: Statistics and metrics\n'
              '- collage: Photo layouts\n'
              '- thematic: Mood pieces\n'
              '- conclusion: Endings and farewells',
            ),
          ],
        );
      }

      return ToolResult(
        content: [TextContent(_formatSuggestions(suggestions, useCase))],
      );
    },
  );
}

List<_TemplateSuggestion> _suggestTemplates({
  required String useCase,
  String? contentType,
  String? mood,
}) {
  final suggestions = <_TemplateSuggestion>[];
  final templateIndex = TemplateIndex.instance;
  final useCaseLower = useCase.toLowerCase();

  // Keywords mapping to templates
  final keywordMatches = <String, List<String>>{
    'year review': [
      'TheNeonGate',
      'StackClimb',
      'LiquidMinutes',
      'TheGridShuffle',
      'ParticleFarewell',
    ],
    'wrapped': [
      'TheNeonGate',
      'StackClimb',
      'OrbitalMetrics',
      'WrappedReceipt',
    ],
    'spotify': ['TheNeonGate', 'TheMixtape', 'FrequencyGlow', 'StackClimb'],
    'music': ['TheMixtape', 'FrequencyGlow', 'MinimalistBeat', 'StackClimb'],
    'stats': [
      'OrbitalMetrics',
      'TheGrowthTree',
      'LiquidMinutes',
      'TheSummaryPoster',
    ],
    'statistics': [
      'OrbitalMetrics',
      'TheGrowthTree',
      'BinaryRain',
      'TheSummaryPoster',
    ],
    'photos': [
      'TheGridShuffle',
      'FloatingPolaroids',
      'BentoRecap',
      'TriptychScroll',
    ],
    'memories': [
      'FloatingPolaroids',
      'TheGridShuffle',
      'RetroPostcard',
      'MosaicReveal',
    ],
    'top 5': ['StackClimb', 'TheSpotlight', 'PerspectiveLadder', 'SlotMachine'],
    'ranking': [
      'StackClimb',
      'SlotMachine',
      'TheSpotlight',
      'FloatingPolaroids',
    ],
    'intro': ['TheNeonGate', 'DigitalMirror', 'VortexTitle', 'TheMixtape'],
    'outro': [
      'ParticleFarewell',
      'TheSignature',
      'TheInfinityLoop',
      'WrappedReceipt',
    ],
    'ending': [
      'ParticleFarewell',
      'TheSummaryPoster',
      'TheSignature',
      'WrappedReceipt',
    ],
    'celebration': ['ParticleFarewell', 'TheNeonGate', 'StackClimb'],
    'neon': ['TheNeonGate', 'FrequencyGlow', 'BinaryRain', 'GlitchReality'],
    'retro': ['TheMixtape', 'RetroPostcard', 'LofiWindow'],
    'minimal': ['MinimalistBeat', 'DigitalMirror', 'TheSignature'],
    'glitch': ['GlitchReality', 'NoiseID', 'BinaryRain'],
    'collage': [
      'TheGridShuffle',
      'BentoRecap',
      'MosaicReveal',
      'SplitPersonality',
    ],
  };

  // Find matching templates based on keywords
  final matchedTemplates = <String, int>{};
  for (final entry in keywordMatches.entries) {
    if (useCaseLower.contains(entry.key)) {
      for (final templateName in entry.value) {
        matchedTemplates[templateName] =
            (matchedTemplates[templateName] ?? 0) + 1;
      }
    }
  }

  // Add content type specific templates
  if (contentType != null) {
    final contentTemplates = <String, List<String>>{
      'year_review': [
        'TheNeonGate',
        'OrbitalMetrics',
        'TheGridShuffle',
        'TheSummaryPoster',
        'ParticleFarewell',
      ],
      'statistics': [
        'OrbitalMetrics',
        'TheGrowthTree',
        'LiquidMinutes',
        'BinaryRain',
      ],
      'photo_gallery': [
        'TheGridShuffle',
        'FloatingPolaroids',
        'BentoRecap',
        'TriptychScroll',
      ],
      'brand_intro': ['TheNeonGate', 'DigitalMirror', 'VortexTitle', 'NoiseID'],
      'social_content': [
        'TheNeonGate',
        'StackClimb',
        'TheGridShuffle',
        'ParticleFarewell',
      ],
      'achievement': [
        'StackClimb',
        'TheSpotlight',
        'OrbitalMetrics',
        'ParticleFarewell',
      ],
      'ranking_list': [
        'StackClimb',
        'SlotMachine',
        'TheSpotlight',
        'PerspectiveLadder',
      ],
    };

    if (contentTemplates.containsKey(contentType)) {
      for (final templateName in contentTemplates[contentType]!) {
        matchedTemplates[templateName] =
            (matchedTemplates[templateName] ?? 0) + 2;
      }
    }
  }

  // Add mood specific templates
  if (mood != null) {
    final moodTemplates = <String, List<String>>{
      'energetic': [
        'TheNeonGate',
        'ParticleFarewell',
        'SlotMachine',
        'GlitchReality',
      ],
      'nostalgic': [
        'FloatingPolaroids',
        'RetroPostcard',
        'TheMixtape',
        'LofiWindow',
      ],
      'professional': [
        'DigitalMirror',
        'OrbitalMetrics',
        'TheSummaryPoster',
        'MinimalistBeat',
      ],
      'playful': [
        'SlotMachine',
        'ParticleFarewell',
        'Kaleidoscope',
        'WrappedReceipt',
      ],
      'dramatic': [
        'TheNeonGate',
        'TheSpotlight',
        'VortexTitle',
        'TheGrowthTree',
      ],
      'minimal': [
        'MinimalistBeat',
        'DigitalMirror',
        'TheSignature',
        'SplitPersonality',
      ],
    };

    if (moodTemplates.containsKey(mood)) {
      for (final templateName in moodTemplates[mood]!) {
        matchedTemplates[templateName] =
            (matchedTemplates[templateName] ?? 0) + 1;
      }
    }
  }

  // Sort by match count and get top suggestions
  final sortedMatches = matchedTemplates.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (final entry in sortedMatches.take(6)) {
    final allTemplates = templateIndex.getAllTemplates();
    final template = allTemplates.firstWhere(
      (t) => t.name == entry.key,
      orElse: () => throw StateError('Template not found'),
    );

    suggestions.add(
      _TemplateSuggestion(
        template: template,
        relevanceScore: entry.value,
        reason: _getReasonForSuggestion(
          template.name,
          useCaseLower,
          contentType,
          mood,
        ),
      ),
    );
  }

  // If no matches, suggest based on category
  if (suggestions.isEmpty) {
    final defaultSuggestions = [
      'TheNeonGate',
      'StackClimb',
      'OrbitalMetrics',
      'TheGridShuffle',
      'ParticleFarewell',
    ];
    for (final name in defaultSuggestions) {
      final allTemplates = templateIndex.getAllTemplates();
      final template = allTemplates.firstWhere(
        (t) => t.name == name,
        orElse: () => throw StateError('Template not found'),
      );
      suggestions.add(
        _TemplateSuggestion(
          template: template,
          relevanceScore: 1,
          reason: 'Popular template for various use cases',
        ),
      );
    }
  }

  return suggestions;
}

String _getReasonForSuggestion(
  String templateName,
  String useCase,
  String? contentType,
  String? mood,
) {
  final reasons = <String>[];

  if (useCase.contains('year') ||
      useCase.contains('review') ||
      useCase.contains('wrapped')) {
    if (templateName == 'TheNeonGate') {
      reasons.add('Great for dramatic year intro');
    }
    if (templateName == 'TheSummaryPoster') {
      reasons.add('Perfect for recap stats');
    }
    if (templateName == 'ParticleFarewell') reasons.add('Celebratory ending');
  }

  if (useCase.contains('photo') || useCase.contains('memor')) {
    if (templateName.contains('Polaroid') || templateName.contains('Grid')) {
      reasons.add('Excellent for photo showcases');
    }
  }

  if (useCase.contains('top') ||
      useCase.contains('rank') ||
      useCase.contains('best')) {
    if (templateName == 'StackClimb' || templateName == 'TheSpotlight') {
      reasons.add('Perfect for ranked lists');
    }
  }

  if (mood != null) {
    reasons.add('Matches $mood mood');
  }

  if (contentType != null) {
    reasons.add('Suitable for ${contentType.replaceAll('_', ' ')}');
  }

  return reasons.isEmpty ? 'Versatile template' : reasons.join(', ');
}

String _formatSuggestions(
  List<_TemplateSuggestion> suggestions,
  String useCase,
) {
  final buffer = StringBuffer();

  buffer.writeln('# Template Suggestions for "$useCase"\n');

  for (var i = 0; i < suggestions.length; i++) {
    final suggestion = suggestions[i];
    final template = suggestion.template;

    buffer.writeln('## ${i + 1}. ${template.name}');
    buffer.writeln('**Category:** ${template.category}');
    buffer.writeln('**Why:** ${suggestion.reason}');
    buffer.writeln();
    buffer.writeln(template.description);
    buffer.writeln();
    buffer.writeln(
      '**Recommended Length:** ${template.recommendedLength} frames (${(template.recommendedLength / 30).toStringAsFixed(1)}s at 30fps)',
    );
    buffer.writeln('**Data Type:** `${template.dataType}`');
    buffer.writeln();
  }

  buffer.writeln('---\n');
  buffer.writeln('## Suggested Video Structure\n');
  buffer
      .writeln('For a complete "$useCase" video, consider this scene order:\n');

  // Suggest a complete video structure
  final intro = suggestions.firstWhere(
    (s) => s.template.category == 'intro',
    orElse: () => suggestions.first,
  );
  final main = suggestions
      .where((s) => !['intro', 'conclusion'].contains(s.template.category))
      .take(2)
      .toList();
  final outro = suggestions.firstWhere(
    (s) => s.template.category == 'conclusion',
    orElse: () => suggestions.last,
  );

  buffer.writeln(
    '1. **Opening:** ${intro.template.name} (${intro.template.category})',
  );
  for (var i = 0; i < main.length; i++) {
    buffer.writeln(
      '${i + 2}. **Content ${i + 1}:** ${main[i].template.name} (${main[i].template.category})',
    );
  }
  buffer.writeln(
    '${main.length + 2}. **Closing:** ${outro.template.name} (${outro.template.category})',
  );

  return buffer.toString();
}

class _TemplateSuggestion {
  final TemplateInfo template;
  final int relevanceScore;
  final String reason;

  const _TemplateSuggestion({
    required this.template,
    required this.relevanceScore,
    required this.reason,
  });
}
