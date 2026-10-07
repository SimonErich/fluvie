/// A curated colour treatment. Intensity is authored on its effects, so a
/// saved/reopened Look remains adjustable and uses the render's interpolation.
final class ColourLook {
  /// Declares a named treatment in a video family.
  const ColourLook(this.name, this.family, this.effects);

  /// The display name of this treatment.
  final String name;

  /// Its intended video family.
  final String family;

  /// The effect declarations at full intensity.
  final List<Map<String, Object?>> effects;

  /// A fresh effect list at [intensity].
  List<Map<String, Object?>> at(double intensity) => [
    for (final effect in effects) {...effect, 'intensity': intensity.clamp(0, 1)},
  ];
}

/// Four grounded starting points, including a portable LUT-backed film look.
const colourLooks = [
  ColourLook('Social pop', 'Social', [
    {'kind': 'grade', 'contrast': 1.12, 'saturation': 1.25, 'exposure': 0.1},
  ]),
  ColourLook('Clear speaker', 'Talks', [
    {'kind': 'grade', 'exposure': 0.2, 'contrast': 1.05, 'temperature': 0.05},
  ]),
  ColourLook('Studio clean', 'Product', [
    {'kind': 'grade', 'contrast': 1.08, 'saturation': 0.9, 'tint': 0.03},
  ]),
  ColourLook('Warm cinema', 'Cinematic', [
    {'kind': 'lut', 'cube': _cinemaCube},
  ]),
];

const _cinemaCube = '''
TITLE "Warm cinema"
LUT_3D_SIZE 2
DOMAIN_MIN 0 0 0
DOMAIN_MAX 1 1 1
0.02 0.025 0.04
0.96 0.025 0.04
0.02 0.96 0.04
0.96 0.96 0.04
0.02 0.025 0.90
0.96 0.025 0.90
0.02 0.96 0.90
0.96 0.96 0.90
''';

/// The effect kinds belonging to a copied colour treatment.
const colourEffectKinds = {'grade', 'curves', 'lut'};
