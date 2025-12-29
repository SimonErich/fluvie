/// Spotify Wrapped-style templates for video composition.
///
/// This library provides a collection of 30 pre-built, customizable templates
/// for creating engaging video content in the style of Spotify Wrapped.
///
/// ## Template Categories
///
/// - **Intro Templates** (5): Opening sequences and identity reveals
///   - [TheNeonGate], [DigitalMirror], [TheMixtape], [VortexTitle], [NoiseID]
///
/// - **Ranking Templates** (5): Top lists and winner reveals
///   - [StackClimb], [SlotMachine], [TheSpotlight], [PerspectiveLadder], [FloatingPolaroids]
///
/// - **Data Visualization Templates** (5): Stats and metrics displays
///   - [OrbitalMetrics], [TheGrowthTree], [LiquidMinutes], [FrequencyGlow], [BinaryRain]
///
/// - **Collage Templates** (5): Multi-image layouts
///   - [TheGridShuffle], [SplitPersonality], [MosaicReveal], [BentoRecap], [TriptychScroll]
///
/// - **Thematic Templates** (5): Mood and aesthetic experiences
///   - [LofiWindow], [GlitchReality], [RetroPostcard], [Kaleidoscope], [MinimalistBeat]
///
/// - **Conclusion Templates** (5): Endings and farewell sequences
///   - [ParticleFarewell], [TheSignature], [TheSummaryPoster], [TheInfinityLoop], [WrappedReceipt]
///
/// ## Usage
///
/// Templates can be used directly in a Video composition:
///
/// ```dart
/// Video(
///   fps: 30,
///   width: 1080,
///   height: 1920,
///   scenes: [
///     TheNeonGate(
///       data: IntroData(title: 'Your 2024', year: 2024),
///       theme: TemplateTheme.neon,
///     ).toScene(),
///
///     StackClimb(
///       data: RankingData(
///         title: 'Top Artists',
///         items: [...],
///       ),
///     ).toScene(),
///
///     ParticleFarewell(
///       data: SummaryData(message: 'See you next year!'),
///     ).toScene(),
///   ],
/// )
/// ```
///
/// ## Customization
///
/// All templates support:
/// - Custom themes via [TemplateTheme]
/// - Custom timing via [TemplateTiming]
/// - Data-driven content via [TemplateData] subclasses
library;

// Base classes
export '_base/base.dart';

// Template categories
export 'intro/intro_templates.dart';
export 'ranking/ranking_templates.dart';
export 'data_viz/data_viz_templates.dart';
export 'collage/collage_templates.dart';
export 'thematic/thematic_templates.dart';
export 'conclusion/conclusion_templates.dart';
