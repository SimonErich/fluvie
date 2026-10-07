// The media bin: folders, search, sort, probed facts and per-asset in/out.
// All of it is editor metadata, so none of it can move the render digest.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

MediaStoreEntry _entry(
  String id,
  String name, {
  MediaStoreKind kind = MediaStoreKind.video,
  String? folder,
  int? sizeBytes,
  String? duration,
  double? fps,
  int? inFrames,
  int? outFrames,
}) => MediaStoreEntry(
  id: id,
  name: name,
  kind: kind,
  source: {'kind': 'file', 'value': '/media/$name'},
  folder: folder,
  sizeBytes: sizeBytes,
  duration: duration,
  fps: fps,
  inFrames: inFrames,
  outFrames: outFrames,
);

void main() {
  group('the listing', () {
    final entries = [
      _entry('m1', 'b-roll.mp4', folder: 'broll', sizeBytes: 300, duration: '4s', fps: 30),
      _entry('m2', 'Interview.mov', folder: 'interviews', sizeBytes: 900, duration: '12s', fps: 25),
      _entry('m3', 'logo.png', kind: MediaStoreKind.image, sizeBytes: 50),
      _entry('m4', 'bed.mp3', kind: MediaStoreKind.audio, folder: 'music', duration: '30s', fps: 1),
    ];

    test('with no query at all it is the store, in import order', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery()).map((e) => e.id),
        ['m1', 'm2', 'm3', 'm4'],
      );
    });

    test('a folder narrows to that folder', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery(folder: 'broll')).map((e) => e.id),
        ['m1'],
      );
    });

    test('no folder means all media, not the unfiled ones', () {
      // An author searching wants to find a file they filed away, not to be
      // told it is not in the current folder.
      expect(mediaBinListing(entries, const MediaBinQuery()), hasLength(4));
    });

    test('search matches the name case-insensitively', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery(search: 'INTER')).map((e) => e.id),
        ['m2'],
      );
    });

    test('search matches the folder too', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery(search: 'music')).map((e) => e.id),
        ['m4'],
      );
    });

    test('a kind filter keeps only those kinds', () {
      expect(
        mediaBinListing(
          entries,
          const MediaBinQuery(kinds: {MediaStoreKind.image, MediaStoreKind.audio}),
        ).map((e) => e.id),
        ['m3', 'm4'],
      );
    });

    test('a folder and a search compose', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery(folder: 'broll', search: 'nope')),
        isEmpty,
      );
    });

    test('sorting by name ignores case', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery(sort: MediaBinSort.name)).map((e) => e.name),
        ['b-roll.mp4', 'bed.mp3', 'Interview.mov', 'logo.png'],
      );
    });

    test('sorting by size is largest first, with unknowns after', () {
      expect(
        mediaBinListing(entries, const MediaBinQuery(sort: MediaBinSort.size)).map((e) => e.id),
        ['m2', 'm1', 'm3', 'm4'],
      );
    });

    test('an unknown value sorts after everything known, not as zero', () {
      // A file whose duration was never probed is not a short file, and
      // sorting it among the short ones would say that it is.
      final mixed = [
        _entry('a', 'a.mp4', duration: '2s', fps: 30),
        _entry('b', 'b.mp4'),
        _entry('c', 'c.mp4', duration: '9s', fps: 30),
      ];

      expect(
        mediaBinListing(mixed, const MediaBinQuery(sort: MediaBinSort.duration)).map((e) => e.id),
        ['c', 'a', 'b'],
      );
      expect(
        mediaBinListing(mixed, const MediaBinQuery(sort: MediaBinSort.size)).map((e) => e.id),
        ['a', 'b', 'c'],
        reason: 'none has a size, so the order is left alone',
      );
    });

    test('the listing is unmodifiable, so a panel cannot edit the store', () {
      final listing = mediaBinListing(entries, const MediaBinQuery());
      expect(() => listing.add(entries.first), throwsUnsupportedError);
    });
  });

  group('folders', () {
    test('are every folder in use, sorted, without the unfiled', () {
      final entries = [
        _entry('m1', 'a.mp4', folder: 'Zebra'),
        _entry('m2', 'b.mp4'),
        _entry('m3', 'c.mp4', folder: 'apple'),
        _entry('m4', 'd.mp4', folder: 'Zebra'),
      ];

      expect(mediaBinFolders(entries), ['apple', 'Zebra']);
    });

    test('an empty store has no folders', () {
      expect(mediaBinFolders(const []), isEmpty);
    });
  });

  group('the query', () {
    test('clearing the folder is distinguishable from leaving it alone', () {
      const query = MediaBinQuery(folder: 'broll', search: 'x');

      expect(query.copyWith(search: 'y').folder, 'broll');
      expect(query.copyWith(clearFolder: true).folder, isNull);
      expect(query.copyWith(clearFolder: true).search, 'x', reason: 'the rest survives');
    });
  });

  group('probed facts and marks', () {
    test('a duration in frames needs both the duration and the rate', () {
      expect(_entry('m', 'a.mp4', duration: '4s', fps: 30).durationFrames, 120);
      expect(_entry('m', 'a.mp4', duration: '4s').durationFrames, isNull);
      expect(_entry('m', 'a.mp4', fps: 30).durationFrames, isNull);
      expect(_entry('m', 'a.mp4', duration: '1500ms', fps: 30).durationFrames, 45);
    });

    test('an unmarked asset ranges over the whole file', () {
      expect(_entry('m', 'a.mp4', duration: '4s', fps: 30).markedRange, (start: 0, end: 120));
    });

    test('marks narrow the range', () {
      final marked = _entry('m', 'a.mp4', duration: '4s', fps: 30, inFrames: 30, outFrames: 90);
      expect(marked.markedRange, (start: 30, end: 90));
    });

    test('an in point alone runs to the end of the file', () {
      final marked = _entry('m', 'a.mp4', duration: '4s', fps: 30, inFrames: 30);
      expect(marked.markedRange, (start: 30, end: 120));
    });

    test('a range that cannot be resolved is null, not invented', () {
      // No duration behind an open out point means no honest end.
      expect(_entry('m', 'a.mp4', inFrames: 30).markedRange, isNull);
      // And an inverted mark is not a range at all.
      expect(
        _entry('m', 'a.mp4', duration: '4s', fps: 30, inFrames: 90, outFrames: 30).markedRange,
        isNull,
      );
    });

    test('copyWith can set a mark and can clear both', () {
      final entry = _entry('m', 'a.mp4', duration: '4s', fps: 30);

      final marked = entry.copyWith(inFrames: 15, outFrames: 45);
      expect(marked.markedRange, (start: 15, end: 45));
      expect(marked.copyWith(clearMarks: true).markedRange, (start: 0, end: 120));
    });

    test('copyWith can file and unfile', () {
      final entry = _entry('m', 'a.mp4');
      expect(entry.copyWith(folder: 'broll').folder, 'broll');
      expect(entry.copyWith(folder: 'broll').copyWith(clearFolder: true).folder, isNull);
    });
  });

  group('the JSON form', () {
    test('round-trips every field', () {
      const entry = MediaStoreEntry(
        id: 'm1',
        name: 'b-roll.mp4',
        kind: MediaStoreKind.video,
        source: {'kind': 'file', 'value': '/media/b-roll.mp4'},
        sizeBytes: 4096,
        duration: '4s',
        folder: 'broll',
        width: 1920,
        height: 1080,
        fps: 29.97,
        inFrames: 12,
        outFrames: 96,
      );

      expect(MediaStoreEntry.fromJson(entry.toJson()), entry);
    });

    test('elides what it does not know, so an old entry still reads', () {
      const bare = MediaStoreEntry(
        id: 'm1',
        name: 'a.mp4',
        kind: MediaStoreKind.video,
        source: {'kind': 'file', 'value': '/a.mp4'},
      );

      expect(bare.toJson().keys, ['id', 'name', 'kind', 'source']);
      expect(MediaStoreEntry.fromJson(bare.toJson()), bare);
    });

    test('a nonsense field reads as absent rather than throwing', () {
      final entry = MediaStoreEntry.fromJson(const {
        'id': 'm1',
        'name': 'a.mp4',
        'kind': 'video',
        'source': {'kind': 'file', 'value': '/a.mp4'},
        'width': -4,
        'in': 'soon',
        'folder': '',
      });

      expect(entry.width, isNull);
      expect(entry.inFrames, isNull);
      expect(entry.folder, isNull, reason: 'an empty folder is unfiled, not a folder named ""');
    });
  });
}
