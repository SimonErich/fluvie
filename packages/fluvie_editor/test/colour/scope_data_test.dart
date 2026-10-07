import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

void main() {
  test('black, white and red frames occupy their expected scope bins', () {
    for (final rgb in [
      [0, 0, 0],
      [255, 255, 255],
      [255, 0, 0],
    ]) {
      final data = ScopeData.fromRgba(Uint8List.fromList([...rgb, 255]), 1, 1);
      expect(data.red[rgb[0]], 1);
      expect(data.green[rgb[1]], 1);
      expect(data.blue[rgb[2]], 1);
      final y = (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]).round();
      expect(data.luma[y], 1);
      expect(data.waveform.reduce((a, b) => a + b), 1);
      expect(data.vectorscope.reduce((a, b) => a + b), 1);
      if (rgb[0] == rgb[1]) expect(data.vectorscope[32 * 64 + 32], 1);
    }
  });
  test('a grayscale ramp has one count per level and neutral chroma', () {
    final data = ScopeData.fromRgba(
      Uint8List.fromList([
        for (var i = 0; i < 256; i++) ...[i, i, i, 255],
      ]),
      256,
      1,
    );
    expect(data.red, everyElement(1));
    expect(data.luma, everyElement(1));
    expect(data.samples, 256);
  });
  testWidgets('requests throttle to the latest frame and reuse settled-frame cache', (
    tester,
  ) async {
    final scopes = ColourScopesController();
    addTearDown(scopes.dispose);
    var calls = 0;
    Future<ScopeData> read() async {
      calls++;
      return ScopeData.fromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
    }

    scopes
      ..request('digest:0', read)
      ..request('digest:1', read)
      ..request('digest:1', read);
    await tester.pump(const Duration(milliseconds: 99));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    scopes.request('digest:1', read);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, 1);
    scopes.request('digest:2', read);
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
  });
  testWidgets('scope display changes leave the document and undo history untouched', (
    tester,
  ) async {
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'scenes': [
        {'duration': '60f'},
      ],
    });
    final history = DocumentHistory(document);
    addTearDown(history.dispose);
    final scopes = ColourScopesController(interval: const Duration(milliseconds: 1));
    addTearDown(scopes.dispose);
    final digest = document.renderDigest;
    await tester.pumpWidget(
      ProviderScope(
        child: OiApp(
          home: ColourPanel(
            document: document,
            onCommand: history.dispatch,
            scopes: scopes,
          ),
        ),
      ),
    );
    scopes.request(
      '$digest:0',
      () async => ScopeData.fromRgba(Uint8List.fromList([255, 0, 0, 255]), 1, 1),
    );
    await tester.pump(const Duration(milliseconds: 1));
    for (final mode in ['Waveform', 'Vectorscope', 'Histogram']) {
      tester.widget<OiSelect<String>>(find.byType(OiSelect<String>)).onChanged!(mode);
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '$mode from 1 preview pixels',
        ),
        findsOneWidget,
      );
    }
    expect(history.document.renderDigest, digest);
    expect(history.document.toJson(), document.toJson());
    expect(history.canUndo, isFalse);
  });

  testWidgets('cached settled frame clears current errors and rejects stale read failures', (
    tester,
  ) async {
    final scopes = ColourScopesController(interval: const Duration(milliseconds: 1));
    addTearDown(scopes.dispose);
    Future<ScopeData> read() async => ScopeData.fromRgba(Uint8List.fromList([0, 0, 0, 255]), 1, 1);
    scopes.request('good', read);
    await tester.pump(const Duration(milliseconds: 1));
    scopes.request('bad', () async => throw StateError('Decode failed'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(scopes.error, contains('Decode failed'));
    scopes.request('good', read);
    expect(scopes.error, isNull);
    final stale = Completer<ScopeData>();
    scopes.request('slow', () => stale.future);
    await tester.pump(const Duration(milliseconds: 1));
    scopes.request('good', read);
    stale.completeError(StateError('An old frame failed'));
    await tester.pump(const Duration(milliseconds: 1));
    expect(scopes.error, isNull);
    expect(scopes.data, isNotNull);
  });
}
