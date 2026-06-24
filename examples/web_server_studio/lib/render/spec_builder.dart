/// Builds a serialized `VideoSpec` (the JSON the render server parses) for a
/// customizable Kitten Mitten promo.
///
/// It is pure data using only core Fluvie element types (a gradient scene with an
/// animated headline), so the server renders it through its capture harness with
/// no `kitten_kit` dependency on the server side.
Map<String, Object?> kittenPromoSpec({
  required String headline,
  String? tagline,
  String accentHex = '#FF8FB1',
}) {
  final hasTagline = tagline != null && tagline.trim().isNotEmpty;
  return {
    'fluvieSpec': 1,
    'size': 'square',
    'fps': 30,
    'scenes': [
      {
        'duration': '5.0s',
        'background': {
          'kind': 'gradient',
          'colors': ['#FFE3D0', accentHex],
          'begin': 'topCenter',
          'end': 'bottomCenter',
        },
        'children': [
          {
            'type': 'Text',
            'text': hasTagline ? '$headline\n$tagline' : headline,
            'style': {'fontSize': 80, 'fontWeight': 'bold', 'color': '#2B2330'},
            'animate': [
              {'preset': 'fadeIn', 'duration': '1.0s'},
            ],
          },
        ],
      },
    ],
  };
}
