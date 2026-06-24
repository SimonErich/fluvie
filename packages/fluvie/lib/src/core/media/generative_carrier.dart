import 'package:fluvie/src/core/media/generative_source.dart';

/// A widget that declares AI-generated media the prerender pass must produce
/// before media resolution, or `null` when it declares none.
///
/// The generic generative elements implement this so the static prerender walk
/// can read the declaration from a `core` contract without importing the element
/// or provider layers (which would invert the layering law). It is a pure
/// structural marker: it carries no IO and no generation, only the
/// already-constructed [GenerativeSource] the element was built with.
///
/// A carrier that also loads or computes media may implement `MediaCarrier`; the
/// two are independent markers gathered by independent walks.
abstract interface class GenerativeCarrier {
  /// The generative media this widget produces, or `null` when it declares none.
  GenerativeSource? get generativeSource;
}
