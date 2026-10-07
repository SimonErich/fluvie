import 'package:fluvie_editor/fluvie_editor.dart' show builtinThemes;

part 'template_pitch.dart';
part 'template_portfolio.dart';
part 'template_report.dart';
part 'template_starter.dart';

/// One spec-based starting deck the gallery offers: a complete `.fluvie`
/// document — its own theme over the shared builtin token vocabulary, the
/// masters its slides adopt, and the slides themselves — so a new deck
/// opens ready and an inserted slide brings what it needs.
final class DeckTemplate {
  /// Describes one template.
  const DeckTemplate({
    required this.id,
    required this.name,
    required this.purpose,
    required this.description,
    required this.deck,
  });

  /// The stable identity ("pitch").
  final String id;

  /// What the gallery calls it.
  final String name;

  /// The gallery's grouping header ("Pitch", "Report").
  final String purpose;

  /// One line on what the template is for.
  final String description;

  /// The complete `.fluvie` document JSON.
  final Map<String, Object?> deck;
}

/// Every built-in template, in gallery order (grouped by purpose).
final List<DeckTemplate> builtinDeckTemplates = List.unmodifiable([
  _pitchTemplate,
  _reportTemplate,
  _portfolioTemplate,
  _starterTemplate,
]);
