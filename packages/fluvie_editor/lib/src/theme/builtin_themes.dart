/// The starter themes the theme panel offers under "Start from".
///
/// All three define one shared token vocabulary — palette `background`,
/// `surface`, `accent`, `text`, `muted`; type scale `title`, `heading`,
/// `body`, `caption`; spacing `s`, `m`, `l`; and motion defaults — so a
/// deck bound to these names restyles wholesale when the theme switches.
/// Each value is a complete top-level `theme` JSON block.
const Map<String, Map<String, Object?>> builtinThemes = {
  'midnight': {
    'palette': {
      'background': '#101018',
      'surface': '#1C1C28',
      'accent': '#6C5CE7',
      'text': '#F9FAFB',
      'muted': '#9CA3AF',
    },
    'typeScale': _typeScale,
    'spacing': _spacing,
    'motion': {'duration': '400ms', 'ease': 'smooth'},
  },
  'paper': {
    'palette': {
      'background': '#F5F1E8',
      'surface': '#FFFFFF',
      'accent': '#C0533F',
      'text': '#262524',
      'muted': '#8A857C',
    },
    'typeScale': _typeScale,
    'spacing': _spacing,
    'motion': {'duration': '300ms', 'ease': 'gentle'},
  },
  'neon': {
    'palette': {
      'background': '#0A0F0D',
      'surface': '#14201A',
      'accent': '#2EFF9A',
      'text': '#E8FFF4',
      'muted': '#5E7A68',
    },
    'typeScale': _typeScale,
    'spacing': _spacing,
    'motion': {'duration': '250ms', 'ease': 'snappy'},
  },
};

/// The shared type scale: typography only — color comes from the palette,
/// so one scale serves light and dark themes alike.
const Map<String, Object?> _typeScale = {
  'title': {'fontSize': 64, 'fontWeight': 'w700'},
  'heading': {'fontSize': 40, 'fontWeight': 'w600'},
  'body': {'fontSize': 24, 'fontWeight': 'w400'},
  'caption': {'fontSize': 16, 'fontWeight': 'w400', 'letterSpacing': 1.2},
};

/// The shared spacing steps, in canvas pixels.
const Map<String, Object?> _spacing = {'s': 12, 'm': 24, 'l': 48};
