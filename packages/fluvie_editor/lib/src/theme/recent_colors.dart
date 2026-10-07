import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The colors picked most recently in this session, newest first — the
/// middle row of every color picker, between the theme palette and the
/// spectrum.
///
/// Session state on purpose: recents follow the person across decks, so
/// they live in the editor scope, not in the document's `editor` block.
final class RecentColorsController extends Notifier<List<Color>> {
  /// How many recents the row keeps.
  static const int capacity = 8;

  @override
  List<Color> build() => const [];

  /// Records a committed pick: [color] moves to the front, duplicates
  /// collapse, and the oldest entry falls off past [capacity].
  void record(Color color) {
    state = [color, ...state.where((recent) => recent != color)].take(capacity).toList();
  }
}

/// The recently picked colors for the mounted editor scope.
final recentColorsProvider = NotifierProvider<RecentColorsController, List<Color>>(
  RecentColorsController.new,
);
