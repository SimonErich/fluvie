import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/editor/autosave_controller.dart';
import 'package:slides/loader/autosave_record.dart';
import 'package:slides/loader/autosave_store.dart';

import 'memory_autosave_store.dart';

final class _ThrowingStore implements AutosaveStore {
  @override
  Future<AutosaveSnapshot?> read(String key) async => throw StateError('read');

  @override
  Future<void> write(
    String key,
    AutosaveRecord record, {
    Map<String, Uint8List> media = const {},
  }) async => throw StateError('write');

  @override
  Future<void> clear(String key) async => throw StateError('clear');
}

final class _Doc {
  String json = '{"v": 1}';
  String digest = 'd1';
  bool dirty = true;
  int notified = 0;
  Map<String, Uint8List> media = const {};
}

AutosaveController _controller(AutosaveStore store, _Doc doc, {String key = 'deck.fluvie'}) =>
    AutosaveController(
      store: store,
      key: key,
      documentJson: () => doc.json,
      documentDigest: () => doc.digest,
      isDirty: () => doc.dirty,
      media: () => doc.media,
      now: () => DateTime.fromMillisecondsSinceEpoch(42000),
      onChanged: () => doc.notified++,
    );

void main() {
  testWidgets('a change writes once, only after the debounce quiets down', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc();
    final autosave = _controller(store, doc)..changed();
    await tester.pump(const Duration(seconds: 1));
    expect(store.writes, 0);

    // A second change inside the window restarts it.
    autosave.changed();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(store.writes, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.writes, 1);

    final record = store.records['deck.fluvie']!;
    expect(record.json, '{"v": 1}');
    expect(record.digest, 'd1');
    expect(record.savedAt, DateTime.fromMillisecondsSinceEpoch(42000));
    expect(autosave.lastAutosaveAt, DateTime.fromMillisecondsSinceEpoch(42000));
    expect(autosave.lastAutosaveDigest, 'd1');
    expect(doc.notified, 1);
    autosave.dispose();
  });

  testWidgets('the referenced session bytes ride the write', (tester) async {
    final store = MemoryAutosaveStore();
    final photo = Uint8List.fromList(const [1, 2, 3]);
    final doc = _Doc()..media = {'media/photo.png': photo};
    final autosave = _controller(store, doc)..changed();
    await tester.pump(const Duration(seconds: 3));

    expect(store.media['deck.fluvie'], {'media/photo.png': photo});

    // The media went out of the document: the next write carries none.
    doc.media = const {};
    autosave.changed();
    await tester.pump(const Duration(seconds: 3));
    expect(store.media, isEmpty);
    autosave.dispose();
  });

  testWidgets('a clean document clears instead of writing (undo back to saved)', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc();
    final autosave = _controller(store, doc)..changed();
    await tester.pump(const Duration(seconds: 3));
    expect(store.records, isNotEmpty);

    doc.dirty = false;
    autosave.changed();
    await tester.pump(const Duration(seconds: 3));
    expect(store.records, isEmpty);
    expect(autosave.lastAutosaveAt, isNull);
    expect(autosave.lastAutosaveDigest, isNull);
    autosave.dispose();
  });

  testWidgets('flush runs a pending write immediately and is quiet otherwise', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc();
    final autosave = _controller(store, doc);

    await autosave.flush();
    expect(store.writes, 0);

    autosave.changed();
    await autosave.flush();
    expect(store.writes, 1);
    // Nothing left pending: time passing writes nothing more.
    await tester.pump(const Duration(seconds: 3));
    expect(store.writes, 1);
    autosave.dispose();
  });

  testWidgets('saved clears the old key, retargets, and re-arms while dirty', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc();
    final autosave = _controller(store, doc, key: 'untitled.fluvie')..changed();
    await tester.pump(const Duration(seconds: 3));
    expect(store.records.keys, ['untitled.fluvie']);

    // The user edited again while the save dialog was up.
    doc
      ..json = '{"v": 2}'
      ..digest = 'd2';
    await autosave.saved('/decks/mine.fluvie');
    expect(autosave.key, '/decks/mine.fluvie');
    expect(store.records, isEmpty);
    expect(autosave.lastAutosaveAt, isNull);

    // Still dirty, so the mid-dialog edit autosaves under the new key.
    await tester.pump(const Duration(seconds: 3));
    expect(store.records.keys, ['/decks/mine.fluvie']);
    expect(store.records['/decks/mine.fluvie']!.digest, 'd2');
    autosave.dispose();
  });

  testWidgets('saved with a clean document does not re-arm', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc()..dirty = false;
    final autosave = _controller(store, doc);

    await autosave.saved('/decks/mine.fluvie');
    await tester.pump(const Duration(seconds: 3));
    expect(store.writes, 0);
    autosave.dispose();
  });

  testWidgets('discard clears and drops any pending write', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc();
    final autosave = _controller(store, doc)..changed();
    await tester.pump(const Duration(seconds: 3));
    autosave.changed();
    await autosave.discard();
    expect(store.records, isEmpty);
    expect(autosave.lastAutosaveAt, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(store.writes, 1);
    autosave.dispose();
  });

  testWidgets('dispose cancels a pending write without touching the store', (tester) async {
    final store = MemoryAutosaveStore();
    final doc = _Doc();
    _controller(store, doc)
      ..changed()
      ..dispose();
    await tester.pump(const Duration(seconds: 3));
    expect(store.writes, 0);
    expect(store.clears, 0);
  });

  testWidgets('a broken store never breaks the caller', (tester) async {
    final doc = _Doc();
    final autosave = _controller(_ThrowingStore(), doc)..changed();
    await tester.pump(const Duration(seconds: 3));
    expect(autosave.lastAutosaveAt, isNull);

    doc.dirty = false;
    autosave.changed();
    await tester.pump(const Duration(seconds: 3));

    doc.dirty = true;
    await autosave.saved('elsewhere.fluvie');
    await autosave.discard();
    expect(autosave.key, 'elsewhere.fluvie');
    autosave.dispose();
  });
}
