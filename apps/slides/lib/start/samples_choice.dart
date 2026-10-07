import 'package:slides/deck/deck_registry.dart';

/// What the samples dialog resolved to.
sealed class SamplesChoice {
  /// Allows the subtypes their const constructors.
  const SamplesChoice();
}

/// Present a bundled sample deck.
final class PresentSample extends SamplesChoice {
  /// Picks [deck] for presentation.
  const PresentSample(this.deck);

  /// The bundled deck to present.
  final DeckEntry deck;
}

/// Open the bundled demo spec in the editor.
final class EditDemoSample extends SamplesChoice {
  /// Picks the demo spec.
  const EditDemoSample();
}
