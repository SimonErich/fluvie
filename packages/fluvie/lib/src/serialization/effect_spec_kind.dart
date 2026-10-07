part of 'effect_spec.dart';

/// The effects an element can carry, and what each one takes.
///
/// Two classes, exactly as the animation pipeline already sorts them: a
/// transform effect wraps the widget and a pixel effect post-processes the
/// result. The class is a property of the kind, so a stack composes the same
/// way however the author happened to type it.
enum EffectSpecKind {
  /// Seeded monochrome film grain over the child.
  grain(pixel: true, params: [EffectParam('amount', min: 0, max: 1, defaultValue: 0.2)]),

  /// Darkened corners.
  vignette(pixel: true, params: [EffectParam('amount', min: 0, max: 1, defaultValue: 0.4)]),

  /// Horizontal CRT lines.
  scanlines(
    pixel: true,
    params: [
      EffectParam('spacing', min: 1, max: 64, defaultValue: 3),
      EffectParam('opacity', min: 0, max: 1, defaultValue: 0.35),
    ],
  ),

  /// A red/blue channel split, in logical pixels.
  chromatic(pixel: true, params: [EffectParam('px', min: 0, max: 64, defaultValue: 2)]),

  /// Exposure, contrast, saturation, temperature and tint composed into one
  /// colour matrix; every default is the neutral value, so a bare grade is
  /// a pixel-for-pixel no-op.
  grade(
    pixel: true,
    params: [
      EffectParam('exposure', min: -3, max: 3, defaultValue: 0),
      EffectParam('contrast', min: 0, max: 2, defaultValue: 1),
      EffectParam('saturation', min: 0, max: 2, defaultValue: 1),
      EffectParam('temperature', min: -1, max: 1, defaultValue: 0),
      EffectParam('tint', min: -1, max: 1, defaultValue: 0),
      EffectParam('intensity', min: 0, max: 1, defaultValue: 1),
    ],
  ),

  /// Gaussian blur of the element, in logical pixels.
  blur(pixel: true, params: [EffectParam('sigma', min: 0, max: 64, defaultValue: 4)]),

  /// An additive glow bloom.
  bloom(pixel: true, params: [EffectParam('amount', min: 0, max: 1, defaultValue: 0.4)]),

  /// Sliced band jitter.
  glitch(
    pixel: true,
    params: [EffectParam('intensity', min: 0, max: 1, defaultValue: 1)],
    flags: ['reverse'],
    enums: {
      'from': ['left', 'right'],
    },
  ),

  /// A seeded particle field, described by the same `particles` object the
  /// `particles` animation preset already reads.
  particles(pixel: true, params: [], objects: ['particles']),

  /// A fragment shader over the child, with author uniforms.
  shader(pixel: true, params: [], strings: ['asset'], objects: ['uniforms']),

  /// A master tone curve and one per channel, applied through a warm
  /// fragment shader; `curves` holds the channel point lists and
  /// `intensity` mixes toward the untouched frame.
  curves(
    pixel: true,
    params: [EffectParam('intensity', min: 0, max: 1, defaultValue: 1)],
    objects: ['curves'],
  ),

  /// A `.cube` 3D LUT applied through a warm fragment shader; `asset` names
  /// the file and `intensity` mixes toward the untouched frame.
  lut(
    pixel: true,
    params: [EffectParam('intensity', min: 0, max: 1, defaultValue: 1)],
    strings: ['asset', 'cube'],
  ),

  /// A depth-scaled drift with the scene.
  parallax(pixel: false, params: [EffectParam('depth', min: -2, max: 2, defaultValue: 0.2)]);

  const EffectSpecKind({
    required bool pixel,
    required this.params,
    this.flags = const [],
    this.strings = const [],
    this.enums = const {},
    this.objects = const [],
  }) : isPixel = pixel;

  /// Whether this effect post-processes pixels (outermost) rather than
  /// wrapping the widget (innermost).
  final bool isPixel;

  /// The numeric parameters it reads.
  final List<EffectParam> params;

  /// The boolean parameters it reads.
  final List<String> flags;

  /// The string parameters it reads.
  final List<String> strings;

  /// The named-choice parameters it reads, each with its allowed values.
  final Map<String, List<String>> enums;

  /// The nested-object parameters it reads, checked here only for being
  /// objects: what is inside one belongs to the codec that reads it.
  final List<String> objects;

  /// Every key this kind accepts beside `kind` and `enabled`.
  Set<String> get knownKeys => {
    for (final param in params) param.name,
    ...flags,
    ...strings,
    ...enums.keys,
    ...objects,
  };

  /// The kind named [raw].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a name Fluvie does not
  /// know, rather than dropping the effect: a stack that quietly lost a layer
  /// would render something the author never wrote.
  static EffectSpecKind fromJson(Object? raw, {List<String> path = const []}) {
    for (final kind in EffectSpecKind.values) {
      if (kind.name == raw) return kind;
    }
    throw FluvieSpecError(
      raw == null
          ? 'An effect needs a "kind"'
          : 'Unknown effect "$raw". Expected one of: '
                '${EffectSpecKind.values.map((k) => k.name).join(', ')}',
      path: path,
    );
  }
}
