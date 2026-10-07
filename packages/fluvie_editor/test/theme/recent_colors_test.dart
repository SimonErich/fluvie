import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  ProviderContainer container() {
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    return scope;
  }

  test('starts empty and records newest first', () {
    final scope = container();
    scope.read(recentColorsProvider.notifier)
      ..record(const Color(0xFF111111))
      ..record(const Color(0xFF222222));
    expect(scope.read(recentColorsProvider), const [Color(0xFF222222), Color(0xFF111111)]);
  });

  test('re-picking a color moves it to the front without a duplicate', () {
    final scope = container();
    scope.read(recentColorsProvider.notifier)
      ..record(const Color(0xFF111111))
      ..record(const Color(0xFF222222))
      ..record(const Color(0xFF111111));
    expect(scope.read(recentColorsProvider), const [Color(0xFF111111), Color(0xFF222222)]);
  });

  test('holds at most eight colors, dropping the oldest', () {
    final scope = container();
    final notifier = scope.read(recentColorsProvider.notifier);
    for (var i = 0; i < 10; i++) {
      notifier.record(Color(0xFF000000 + i));
    }
    final recents = scope.read(recentColorsProvider);
    expect(recents, hasLength(8));
    expect(recents.first, const Color(0xFF000009));
    expect(recents.contains(const Color(0xFF000000)), isFalse);
  });
}
