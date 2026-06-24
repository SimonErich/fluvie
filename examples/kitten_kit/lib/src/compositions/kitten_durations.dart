import 'package:fluvie/fluvie.dart';

/// Shared clip lengths so each app's render call agrees with the composition
/// builder it renders (the renderers take a duration; the builders set the
/// scene length to match).
abstract final class KittenDurations {
  /// The promo clip length (landscape product spot).
  static const Time promo = Time.seconds(5);

  /// The birthday card length (square social post).
  static const Time card = Time.seconds(6);

  /// The meme clip length (square, short).
  static const Time meme = Time.seconds(4);
}
