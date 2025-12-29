/// Information about a Fluvie template
class TemplateInfo {
  final String name;
  final String category;
  final String description;
  final int recommendedLength;
  final String dataType;
  final List<String> requiredFields;
  final List<String> optionalFields;
  final String defaultTheme;
  final String defaultTiming;
  final Map<String, Map<String, dynamic>> properties;

  const TemplateInfo({
    required this.name,
    required this.category,
    required this.description,
    required this.recommendedLength,
    required this.dataType,
    required this.requiredFields,
    this.optionalFields = const [],
    this.defaultTheme = 'spotify',
    this.defaultTiming = 'standard',
    this.properties = const {},
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'description': description,
        'recommendedLength': recommendedLength,
        'dataType': dataType,
        'requiredFields': requiredFields,
        'optionalFields': optionalFields,
        'defaultTheme': defaultTheme,
        'defaultTiming': defaultTiming,
        'properties': properties,
      };
}

/// Index of all Fluvie templates
class TemplateIndex {
  static TemplateIndex? _instance;
  static TemplateIndex get instance => _instance ??= TemplateIndex._();

  TemplateIndex._();

  final Map<String, Map<String, TemplateInfo>> _templates = {
    'intro': {
      'TheNeonGate': const TemplateInfo(
        name: 'TheNeonGate',
        category: 'intro',
        description:
            'A dramatic neon portal with glowing rings and text sliding through the center. Creates a high-energy opening with particle effects.',
        recommendedLength: 150,
        dataType: 'IntroData',
        requiredFields: ['title'],
        optionalFields: ['subtitle', 'year', 'logoPath', 'userName', 'profileImagePath'],
        defaultTheme: 'neon',
        defaultTiming: 'dramatic',
        properties: {
          'ringCount': {'type': 'int', 'default': 5, 'description': 'Number of concentric rings'},
          'showParticles': {'type': 'bool', 'default': true, 'description': 'Show sparkle particles'},
          'animateRotation': {'type': 'bool', 'default': true, 'description': 'Rotate rings'},
        },
      ),
      'DigitalMirror': const TemplateInfo(
        name: 'DigitalMirror',
        category: 'intro',
        description:
            'Reflective glass effect with a breathing profile cutout and mirrored animations. Modern and sleek.',
        recommendedLength: 120,
        dataType: 'IntroData',
        requiredFields: ['title'],
        optionalFields: ['subtitle', 'profileImagePath'],
        defaultTheme: 'minimal',
      ),
      'TheMixtape': const TemplateInfo(
        name: 'TheMixtape',
        category: 'intro',
        description:
            'Cassette tape-inspired retro intro with stop-motion style animation and dynamic label.',
        recommendedLength: 150,
        dataType: 'IntroData',
        requiredFields: ['title'],
        optionalFields: ['subtitle', 'year'],
        defaultTheme: 'retro',
      ),
      'VortexTitle': const TemplateInfo(
        name: 'VortexTitle',
        category: 'intro',
        description:
            'Typography spiraling from corners to center with a vortex effect. Bold and attention-grabbing.',
        recommendedLength: 120,
        dataType: 'IntroData',
        requiredFields: ['title'],
        optionalFields: ['subtitle'],
      ),
      'NoiseID': const TemplateInfo(
        name: 'NoiseID',
        category: 'intro',
        description:
            'Grunge texture with ink-bleed stamp effect. Underground and edgy aesthetic.',
        recommendedLength: 120,
        dataType: 'IntroData',
        requiredFields: ['title'],
        optionalFields: ['subtitle', 'userName'],
        defaultTheme: 'minimal',
      ),
    },
    'ranking': {
      'StackClimb': const TemplateInfo(
        name: 'StackClimb',
        category: 'ranking',
        description:
            'Cards stack and climb upward, revealing ranked items from bottom to top. Perfect for top 5 lists.',
        recommendedLength: 180,
        dataType: 'RankingData',
        requiredFields: ['items'],
        optionalFields: ['title', 'subtitle', 'isTopList'],
      ),
      'SlotMachine': const TemplateInfo(
        name: 'SlotMachine',
        category: 'ranking',
        description:
            'Slot machine-style rolling reveal with spinning reels. Exciting and suspenseful.',
        recommendedLength: 200,
        dataType: 'RankingData',
        requiredFields: ['items'],
        optionalFields: ['title'],
      ),
      'TheSpotlight': const TemplateInfo(
        name: 'TheSpotlight',
        category: 'ranking',
        description:
            'Items step into a spotlight one by one with dramatic lighting effects.',
        recommendedLength: 180,
        dataType: 'RankingData',
        requiredFields: ['items'],
        optionalFields: ['title', 'subtitle'],
      ),
      'PerspectiveLadder': const TemplateInfo(
        name: 'PerspectiveLadder',
        category: 'ranking',
        description:
            '3D perspective ladder effect with items ascending. Creates depth and hierarchy.',
        recommendedLength: 180,
        dataType: 'RankingData',
        requiredFields: ['items'],
        optionalFields: ['title'],
      ),
      'FloatingPolaroids': const TemplateInfo(
        name: 'FloatingPolaroids',
        category: 'ranking',
        description:
            'Polaroid photos floating in space with gentle motion. Nostalgic and personal.',
        recommendedLength: 200,
        dataType: 'RankingData',
        requiredFields: ['items'],
        optionalFields: ['title'],
      ),
    },
    'data_viz': {
      'OrbitalMetrics': const TemplateInfo(
        name: 'OrbitalMetrics',
        category: 'data_viz',
        description:
            'Metrics orbiting around a central point with animated data points. Futuristic and dynamic.',
        recommendedLength: 180,
        dataType: 'MetricsData',
        requiredFields: ['metrics'],
        optionalFields: ['title', 'subtitle'],
      ),
      'TheGrowthTree': const TemplateInfo(
        name: 'TheGrowthTree',
        category: 'data_viz',
        description:
            'Data growing up a tree structure with branches representing different metrics.',
        recommendedLength: 180,
        dataType: 'MetricsData',
        requiredFields: ['metrics'],
        optionalFields: ['title'],
      ),
      'LiquidMinutes': const TemplateInfo(
        name: 'LiquidMinutes',
        category: 'data_viz',
        description:
            'Liquid fill animation representing time or progress. Smooth and satisfying.',
        recommendedLength: 150,
        dataType: 'MetricsData',
        requiredFields: ['metrics'],
        optionalFields: ['title', 'unit'],
      ),
      'FrequencyGlow': const TemplateInfo(
        name: 'FrequencyGlow',
        category: 'data_viz',
        description:
            'Audio frequency-style visualization with glowing bars. Great for music stats.',
        recommendedLength: 180,
        dataType: 'MetricsData',
        requiredFields: ['metrics'],
        optionalFields: ['title'],
        defaultTheme: 'neon',
      ),
      'BinaryRain': const TemplateInfo(
        name: 'BinaryRain',
        category: 'data_viz',
        description:
            'Matrix-style binary digits raining down with data reveals. Tech-focused aesthetic.',
        recommendedLength: 180,
        dataType: 'MetricsData',
        requiredFields: ['metrics'],
        optionalFields: ['title'],
        defaultTheme: 'neon',
      ),
    },
    'collage': {
      'TheGridShuffle': const TemplateInfo(
        name: 'TheGridShuffle',
        category: 'collage',
        description:
            'Grid of images that shuffle and reveal in a dynamic pattern. Great for photo collections.',
        recommendedLength: 180,
        dataType: 'CollageData',
        requiredFields: ['images'],
        optionalFields: ['title', 'gridSize'],
      ),
      'SplitPersonality': const TemplateInfo(
        name: 'SplitPersonality',
        category: 'collage',
        description:
            'Split-screen image comparison with smooth transitions. Perfect for before/after or comparisons.',
        recommendedLength: 150,
        dataType: 'CollageData',
        requiredFields: ['images'],
        optionalFields: ['title'],
      ),
      'MosaicReveal': const TemplateInfo(
        name: 'MosaicReveal',
        category: 'collage',
        description:
            'Mosaic tiles gradually revealing a larger image. Creates anticipation and surprise.',
        recommendedLength: 180,
        dataType: 'CollageData',
        requiredFields: ['images'],
        optionalFields: ['title', 'tileCount'],
      ),
      'BentoRecap': const TemplateInfo(
        name: 'BentoRecap',
        category: 'collage',
        description:
            'Bento box grid layout with different sized cells. Modern and organized.',
        recommendedLength: 180,
        dataType: 'CollageData',
        requiredFields: ['images'],
        optionalFields: ['title'],
      ),
      'TriptychScroll': const TemplateInfo(
        name: 'TriptychScroll',
        category: 'collage',
        description:
            'Three-panel horizontal scroll with Ken Burns effect. Cinematic and elegant.',
        recommendedLength: 200,
        dataType: 'CollageData',
        requiredFields: ['images'],
        optionalFields: ['title'],
      ),
    },
    'thematic': {
      'LofiWindow': const TemplateInfo(
        name: 'LofiWindow',
        category: 'thematic',
        description:
            'Lofi aesthetic with cozy window scene and subtle animations. Chill and relaxing.',
        recommendedLength: 180,
        dataType: 'ThematicData',
        requiredFields: ['text'],
        optionalFields: ['mood', 'primaryColor'],
        defaultTheme: 'pastel',
      ),
      'GlitchReality': const TemplateInfo(
        name: 'GlitchReality',
        category: 'thematic',
        description:
            'Digital glitch effects with RGB splitting and distortion. Edgy and cyberpunk.',
        recommendedLength: 150,
        dataType: 'ThematicData',
        requiredFields: ['text'],
        optionalFields: ['glitchIntensity'],
        defaultTheme: 'neon',
      ),
      'RetroPostcard': const TemplateInfo(
        name: 'RetroPostcard',
        category: 'thematic',
        description:
            'Vintage postcard aesthetic with aged textures and nostalgic colors.',
        recommendedLength: 150,
        dataType: 'ThematicData',
        requiredFields: ['text'],
        optionalFields: ['imagePath'],
        defaultTheme: 'retro',
      ),
      'Kaleidoscope': const TemplateInfo(
        name: 'Kaleidoscope',
        category: 'thematic',
        description:
            'Kaleidoscopic pattern generation with symmetric animations. Hypnotic and artistic.',
        recommendedLength: 180,
        dataType: 'ThematicData',
        requiredFields: ['text'],
        optionalFields: ['primaryColor', 'segments'],
      ),
      'MinimalistBeat': const TemplateInfo(
        name: 'MinimalistBeat',
        category: 'thematic',
        description:
            'Minimal design with beat-synced visual elements. Clean and rhythmic.',
        recommendedLength: 180,
        dataType: 'ThematicData',
        requiredFields: ['text'],
        optionalFields: ['bpm'],
        defaultTheme: 'minimal',
      ),
    },
    'conclusion': {
      'ParticleFarewell': const TemplateInfo(
        name: 'ParticleFarewell',
        category: 'conclusion',
        description:
            'Particle explosion farewell with confetti and celebration effects.',
        recommendedLength: 150,
        dataType: 'SummaryData',
        requiredFields: ['message'],
        optionalFields: ['year', 'stats'],
      ),
      'TheSignature': const TemplateInfo(
        name: 'TheSignature',
        category: 'conclusion',
        description:
            'Signature-style ending with handwritten animation effect. Personal and authentic.',
        recommendedLength: 120,
        dataType: 'SummaryData',
        requiredFields: ['message'],
        optionalFields: ['authorName'],
      ),
      'TheSummaryPoster': const TemplateInfo(
        name: 'TheSummaryPoster',
        category: 'conclusion',
        description:
            'Summary poster layout with key stats and highlights. Comprehensive wrap-up.',
        recommendedLength: 180,
        dataType: 'SummaryData',
        requiredFields: ['message'],
        optionalFields: ['stats', 'highlights'],
      ),
      'TheInfinityLoop': const TemplateInfo(
        name: 'TheInfinityLoop',
        category: 'conclusion',
        description:
            'Infinity symbol animation suggesting continuation. Hopeful and forward-looking.',
        recommendedLength: 120,
        dataType: 'SummaryData',
        requiredFields: ['message'],
        optionalFields: ['year'],
      ),
      'WrappedReceipt': const TemplateInfo(
        name: 'WrappedReceipt',
        category: 'conclusion',
        description:
            'Receipt-style summary with itemized stats. Fun and shareable format.',
        recommendedLength: 180,
        dataType: 'SummaryData',
        requiredFields: ['message'],
        optionalFields: ['stats', 'total'],
      ),
    },
  };

  /// Get a specific template
  Future<TemplateInfo?> getTemplate(String category, String name) async {
    return _templates[category]?[name];
  }

  /// Get all templates
  List<TemplateInfo> getAllTemplates() {
    return _templates.values.expand((m) => m.values).toList();
  }

  /// Get templates by category
  List<TemplateInfo> getTemplatesByCategory(String category) {
    return _templates[category]?.values.toList() ?? [];
  }

  /// Get all categories
  List<String> get categories => _templates.keys.toList();

  /// Search templates by keyword
  List<TemplateInfo> searchTemplates(String query) {
    final queryLower = query.toLowerCase();
    return getAllTemplates().where((t) {
      return t.name.toLowerCase().contains(queryLower) ||
          t.description.toLowerCase().contains(queryLower) ||
          t.category.toLowerCase().contains(queryLower);
    }).toList();
  }
}
