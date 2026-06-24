import 'package:flutter/widgets.dart' show Color;
import 'package:fluvie/fluvie.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// One pickable studio template: a CLI render [key] and the kitten promo it
/// builds. Templates are media-less (no audio, image, or clip), so the bundled
/// self-contained capture harness renders them with no extra setup.
class StudioTemplate {
  /// Creates a template.
  const StudioTemplate({
    required this.key,
    required this.label,
    required this.headline,
    required this.tagline,
    required this.fur,
  });

  /// The `fluvie render <key>` key.
  final String key;

  /// The label shown in the picker.
  final String label;

  /// The promo headline.
  final String headline;

  /// The promo tagline.
  final String tagline;

  /// The kitten fur color.
  final Color fur;

  /// Builds the composition this template renders.
  Video build() => kittenPromo(
    headline: headline,
    tagline: tagline,
    fur: fur,
    withMusic: false,
  );
}

/// The studio's templates, registered by key in the capture harness.
const List<StudioTemplate> studioTemplates = <StudioTemplate>[
  StudioTemplate(
    key: 'studio_promo',
    label: 'Promo',
    headline: 'Kitten Mitten',
    tagline: 'Cozy paws, happy days',
    fur: KittenColors.tabby,
  ),
  StudioTemplate(
    key: 'studio_birthday',
    label: 'Birthday',
    headline: 'Happy Birthday!',
    tagline: 'Treats all day',
    fur: KittenColors.mitten,
  ),
  StudioTemplate(
    key: 'studio_meme',
    label: 'Meme',
    headline: 'Such wow',
    tagline: 'very kitten, much cute',
    fur: KittenColors.sky,
  ),
];

/// The template registered under [key].
StudioTemplate templateForKey(String key) =>
    studioTemplates.firstWhere((template) => template.key == key);
