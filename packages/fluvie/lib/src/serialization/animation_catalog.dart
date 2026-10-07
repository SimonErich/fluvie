/// @docImport 'package:fluvie/src/serialization/animation_builder.dart';
library;

/// The animation vocabulary of the spec: which presets exist and which
/// arguments each one reads — the single source of truth shared by the
/// parser, the unknown-property check, and `videoSpecSchema`; it must stay
/// in step with what [buildAnimation] actually reads.

/// The preset names the spec can build, kept as a set so an unknown preset
/// fails at parse time.
const Set<String> knownAnimationPresets = {
  'fadeIn',
  'fadeOut',
  'slideIn',
  'slideOut',
  'slideFadeIn',
  'slideFadeOut',
  'pop',
  'scaleIn',
  'scaleOut',
  'blurIn',
  'blurOut',
  'grain',
  'vignette',
  'spin',
  'drift',
  'kenBurns',
  'maskWipeIn',
  'maskWipeOut',
  'glitchIn',
  'glitchOut',
  'float',
  'pulse',
  'color',
  'gradientShift',
  'scanlines',
  'chromatic',
  'bloom',
  'parallax',
  'particles',
  'shader',
  'scaleY',
  'along',
};

/// The argument keys of the multi-stop `keyframes` form (self-naming, like
/// the raw `from`/`to` forms): the stop list itself, the per-segment
/// `easings`, the per-stop `positions`, and the `phase`. The stop positions
/// are `positions` — never `at`, which stays the start trigger in the timing
/// tail. Shared by the unknown-property check and `videoSpecSchema`.
const Set<String> knownKeyframesFormKeys = {'keyframes', 'easings', 'positions', 'phase'};

/// The arguments each preset reads, beyond the reserved timing-tail keys
/// (`preset`, `duration`, `ease`, `spring`, `delay`, `at`, `stagger`,
/// `repeat`, `label`). Shared by the parser's unknown-property check so a
/// misspelled argument is reported instead of silently dropped.
const Map<String, Set<String>> knownAnimationPresetArgs = {
  'fadeIn': {},
  'fadeOut': {},
  'slideIn': {'from'},
  'slideOut': {'to'},
  'slideFadeIn': {'from'},
  'slideFadeOut': {'to'},
  'pop': {'overshoot'},
  'scaleIn': {'from'},
  'scaleOut': {'to'},
  'blurIn': {'sigma'},
  'blurOut': {'sigma'},
  'grain': {'amount'},
  'vignette': {'amount'},
  'spin': {'period'},
  'drift': {'to', 'distance'},
  'kenBurns': {'zoom', 'pan'},
  'maskWipeIn': {'shape', 'origin'},
  'maskWipeOut': {'shape', 'origin'},
  'glitchIn': {'from'},
  'glitchOut': {'to'},
  'float': {'amplitude', 'period', 'seed'},
  'pulse': {'on', 'gain', 'track', 'min', 'max', 'period'},
  'color': {'to'},
  'gradientShift': {'to'},
  'scanlines': {},
  'chromatic': {'px'},
  'bloom': {'amount'},
  'parallax': {'depth'},
  'particles': {'spec'},
  'shader': {'asset', 'uniforms'},
  'scaleY': {'on', 'gain', 'track'},
  'along': {'path', 'orient', 'phase'},
};
