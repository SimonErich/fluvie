import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/templates/deck_templates.dart';

void main() {
  test('the gallery ships at least four templates with unique ids', () {
    expect(builtinDeckTemplates.length, greaterThanOrEqualTo(4));
    final ids = [for (final template in builtinDeckTemplates) template.id];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('templates are organized by purpose', () {
    final purposes = {for (final template in builtinDeckTemplates) template.purpose};
    expect(purposes.length, greaterThanOrEqualTo(3), reason: 'distinct purposes group the gallery');
    for (final template in builtinDeckTemplates) {
      expect(template.purpose, isNotEmpty);
      expect(template.name, isNotEmpty);
      expect(template.description, isNotEmpty);
    }
  });

  test('every template is a valid deck that opens, builds, and presents', () {
    for (final template in builtinDeckTemplates) {
      final document = EditorDocument.fromJson(template.deck);
      expect(document.sceneCount, greaterThanOrEqualTo(1), reason: template.id);
      // Building proves masters resolve and every token reference lands.
      expect(document.spec.build, returnsNormally, reason: template.id);
    }
  });

  test('every template ships its own theme over the shared vocabulary', () {
    for (final template in builtinDeckTemplates) {
      final theme = EditorDocument.fromJson(template.deck).themeJson;
      expect(theme, isNotNull, reason: template.id);
      final palette = theme!['palette']! as Map<String, Object?>;
      // The builtin vocabulary (7.3): decks restyle when the theme switches.
      for (final token in const ['background', 'surface', 'accent', 'text', 'muted']) {
        expect(palette.containsKey(token), isTrue, reason: '${template.id} palette $token');
      }
      expect(theme['typeScale'], isNotNull, reason: template.id);
    }
  });

  test('every template carries a master and adoption', () {
    for (final template in builtinDeckTemplates) {
      final document = EditorDocument.fromJson(template.deck);
      expect(document.masterNames, isNotEmpty, reason: template.id);
      expect(document.sceneMasterName(0), isNotNull, reason: template.id);
    }
  });

  test('a template restyles when the deck theme switches', () {
    final pitch = builtinDeckTemplates.first;
    final document = EditorDocument.fromJson(pitch.deck);
    final before = document.renderDigest;
    final restyled = document.updateVideo({'theme': builtinThemes['paper']});
    expect(restyled.renderDigest, isNot(before));
    expect(restyled.spec.build, returnsNormally, reason: 'token bindings survive the switch');
  });
}
