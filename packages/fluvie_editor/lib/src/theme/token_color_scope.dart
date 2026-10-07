import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show ValueChanged, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:fluvie/fluvie.dart' show decodeColor;
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/theme/recent_colors.dart';
import 'package:fluvie_editor/src/widgets/named_color.dart';

/// What an inspector color editor needs beyond its literal value: the theme
/// palette to bind against, the session's recent picks, and the recents
/// recorder. [resolve] reads raw spec color JSON that may be a
/// `{"token": name}` binding.
@immutable
final class TokenColorScope {
  /// A scope of [tokens] and [recents]; committed picks land in [onPicked].
  const TokenColorScope({this.tokens = const [], this.recents = const [], this.onPicked});

  /// The tokenless scope: color fields fall back to plain literal editing.
  static const TokenColorScope none = TokenColorScope();

  /// The theme's palette as named swatches, in declaration order.
  final List<NamedColor> tokens;

  /// The session's recent picks, newest first.
  final List<Color> recents;

  /// Hears each committed literal pick (the recents recorder), or null.
  final ValueChanged<Color>? onPicked;

  /// The token name a raw spec color value is bound to (`{"token": name}`),
  /// or null for literals and absent values.
  static String? boundTokenOf(Object? raw) {
    if (raw is! Map) return null;
    final token = raw['token'];
    return token is String ? token : null;
  }

  /// The color [raw] shows: a bound token resolves against [tokens] (or
  /// [fallback] for a name the palette lost), a literal decodes, and null
  /// reads as [fallback].
  Color resolve(Object? raw, Color fallback) {
    final bound = boundTokenOf(raw);
    if (bound != null) {
      for (final token in tokens) {
        if (token.name == bound) return token.color;
      }
      return fallback;
    }
    return raw == null ? fallback : decodeColor(raw, path: const ['color']);
  }
}

/// The [TokenColorScope] for [document] in the editor scope behind [ref]:
/// palette tokens from the deck's theme, recents from the session store.
TokenColorScope tokenColorScopeFor(EditorDocument document, WidgetRef ref) => TokenColorScope(
  tokens: [
    for (final entry in (document.spec.theme?.palette ?? const {}).entries)
      NamedColor(name: entry.key, color: entry.value),
  ],
  recents: ref.watch(recentColorsProvider),
  onPicked: ref.read(recentColorsProvider.notifier).record,
);
