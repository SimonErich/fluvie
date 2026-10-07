import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    <String, Object?>{
      'duration': '120f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Image',
          'source': {'kind': 'file', 'value': '/decks/photo.png'},
        },
      ],
    },
  ],
};

MediaStoreEntry _entry({String id = 'media-1', String value = 'media/photo.png'}) =>
    MediaStoreEntry(
      id: id,
      name: 'photo.png',
      kind: MediaStoreKind.image,
      source: {'kind': 'bundle', 'value': value},
      sizeBytes: 4,
    );

void main() {
  group('MediaStoreEntry', () {
    test('round-trips its JSON form, optional fields elided', () {
      const full = MediaStoreEntry(
        id: 'media-2',
        name: 'bed.mp3',
        kind: MediaStoreKind.audio,
        source: {'kind': 'bundle', 'value': 'media/bed.mp3'},
        sizeBytes: 1024,
        duration: '90f',
      );
      expect(MediaStoreEntry.fromJson(full.toJson()).toJson(), full.toJson());

      final lean = _entry();
      expect(lean.toJson(), {
        'id': 'media-1',
        'name': 'photo.png',
        'kind': 'image',
        'source': {'kind': 'bundle', 'value': 'media/photo.png'},
        'bytes': 4,
      });
      expect(MediaStoreEntry.fromJson(lean.toJson()).duration, isNull);
    });

    test('rejects an unknown kind', () {
      expect(
        () => MediaStoreEntry.fromJson(const {
          'id': 'media-1',
          'name': 'x',
          'kind': 'hologram',
          'source': {'kind': 'file', 'value': '/x'},
        }),
        throwsFormatException,
      );
    });
  });

  group('EditorDocument media entries', () {
    test('start empty, append in order, and survive the JSON round-trip', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.mediaEntries, isEmpty);
      final one = document.addMediaEntry(_entry());
      final two = one.addMediaEntry(
        const MediaStoreEntry(
          id: 'media-2',
          name: 'clip.mp4',
          kind: MediaStoreKind.video,
          source: {'kind': 'file', 'value': '/decks/clip.mp4'},
        ),
      );
      expect(two.mediaEntries.map((entry) => entry.id), ['media-1', 'media-2']);
      final reloaded = EditorDocument.fromJson(two.toJson());
      expect(reloaded.mediaEntries.map((entry) => entry.name), ['photo.png', 'clip.mp4']);
    });

    test('the store lives in the editor block: the render digest never moves', () {
      final document = EditorDocument.fromJson(_deck());
      final withEntry = document.addMediaEntry(_entry());
      expect(withEntry.renderDigest, document.renderDigest);
      expect(withEntry.documentDigest, isNot(document.documentDigest));
    });

    test('removeMediaEntry drops one entry by id and throws for an unknown id', () {
      final document = EditorDocument.fromJson(_deck()).addMediaEntry(_entry());
      expect(document.removeMediaEntry('media-1').mediaEntries, isEmpty);
      expect(() => document.removeMediaEntry('media-9'), throwsArgumentError);
    });

    test('a duplicate id is rejected', () {
      final document = EditorDocument.fromJson(_deck()).addMediaEntry(_entry());
      expect(() => document.addMediaEntry(_entry()), throwsArgumentError);
    });

    test('nextMediaId mints past every held entry', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.nextMediaId(), 'media-1');
      expect(document.addMediaEntry(_entry(id: 'media-3')).nextMediaId(), 'media-4');
    });
  });

  group('EditorDocument deck meta', () {
    test('is empty by default, merges writes, and a null value removes its key', () {
      final document = EditorDocument.fromJson(_deck());
      expect(document.deckMeta, isEmpty);
      final written = document.setDeckMeta({'mediaWarning': 'suppressed', 'mode': 'slides'});
      expect(written.deckMeta, {'mediaWarning': 'suppressed', 'mode': 'slides'});
      final cleared = written.setDeckMeta({'mediaWarning': null});
      expect(cleared.deckMeta, {'mode': 'slides'});
      expect(written.renderDigest, document.renderDigest);
    });
  });

  group('media commands', () {
    test('AddMediaEntryCommand appends and undoes as one step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(AddMediaEntryCommand(entry: _entry()));
      expect(history.document.mediaEntries.single.name, 'photo.png');
      expect(history.canUndo, isTrue);
      history.undo();
      expect(history.document.mediaEntries, isEmpty);
    });

    test('RemoveMediaEntryCommand drops by id and undo restores the entry', () {
      final history = DocumentHistory(
        EditorDocument.fromJson(_deck()).addMediaEntry(_entry()),
      )..dispatch(const RemoveMediaEntryCommand(id: 'media-1'));
      expect(history.document.mediaEntries, isEmpty);
      history.undo();
      expect(history.document.mediaEntries.single.id, 'media-1');
    });

    test('SetDeckMetaCommand writes the deck channel', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(const SetDeckMetaCommand(meta: {'mediaWarning': 'suppressed'}));
      expect(history.document.deckMeta['mediaWarning'], 'suppressed');
      history.undo();
      expect(history.document.deckMeta, isEmpty);
    });

    test('media commands touch no element ids and carry labels', () {
      expect(AddMediaEntryCommand(entry: _entry()).affectedIds, isEmpty);
      expect(const RemoveMediaEntryCommand(id: 'media-1').affectedIds, isEmpty);
      expect(const SetDeckMetaCommand(meta: {}).affectedIds, isEmpty);
      expect(AddMediaEntryCommand(entry: _entry()).label, contains('photo.png'));
      expect(const RemoveMediaEntryCommand(id: 'media-1').label, contains('media-1'));
      expect(const SetDeckMetaCommand(meta: {}).label, isNotEmpty);
    });
  });

  group('storeEntryFor', () {
    test('turns a named pick into a fresh entry with the pick metadata', () {
      final document = EditorDocument.fromJson(_deck());
      final entry = storeEntryFor(
        document,
        const MediaPick(
          source: {'kind': 'bundle', 'value': 'media/b-roll.mp4'},
          isVideo: true,
          name: 'b-roll.mp4',
          sizeBytes: 99,
        ),
      );
      expect(entry, isNotNull);
      expect(entry!.id, 'media-1');
      expect(entry.kind, MediaStoreKind.video);
      expect(entry.name, 'b-roll.mp4');
      expect(entry.sizeBytes, 99);
    });

    test('classifies an audio pick and keeps image the default', () {
      final document = EditorDocument.fromJson(_deck());
      final audio = storeEntryFor(
        document,
        const MediaPick(
          source: {'kind': 'bundle', 'value': 'media/bed.mp3'},
          isVideo: false,
          isAudio: true,
          name: 'bed.mp3',
        ),
      );
      expect(audio!.kind, MediaStoreKind.audio);
      final image = storeEntryFor(
        document,
        const MediaPick(
          source: {'kind': 'file', 'value': '/x.png'},
          isVideo: false,
          name: 'x.png',
        ),
      );
      expect(image!.kind, MediaStoreKind.image);
    });

    test('returns null for a nameless reuse pick and for an already-stored source', () {
      final document = EditorDocument.fromJson(_deck());
      expect(
        storeEntryFor(
          document,
          const MediaPick(source: {'kind': 'file', 'value': '/x.png'}, isVideo: false),
        ),
        isNull,
      );
      final stored = document.addMediaEntry(_entry());
      expect(
        storeEntryFor(
          stored,
          const MediaPick(
            source: {'kind': 'bundle', 'value': 'media/photo.png'},
            isVideo: false,
            name: 'photo.png',
          ),
        ),
        isNull,
      );
    });
  });

  group('referencedBundleValues', () {
    test('collects bundle sources from elements, posters, and audio, not the editor block', () {
      final document = EditorDocument.fromJson(const {
        'fluvieSpec': 1,
        'size': {'width': 320, 'height': 180},
        'fps': 30,
        'audio': [
          {
            'kind': 'music',
            'source': {'kind': 'bundle', 'value': 'media/bed.mp3'},
          },
        ],
        'scenes': [
          {
            'duration': '60f',
            'audio': [
              {
                'kind': 'sfx',
                'source': {'kind': 'bundle', 'value': 'media/pop.wav'},
              },
            ],
            'children': [
              {
                'id': 'el-clip',
                'type': 'Clip',
                'source': {'kind': 'bundle', 'value': 'media/b-roll.mp4'},
                'poster': {'kind': 'bundle', 'value': 'media/poster.png'},
              },
              {
                'id': 'el-group',
                'type': 'Group',
                'children': [
                  {
                    'id': 'el-nested',
                    'type': 'Image',
                    'source': {'kind': 'bundle', 'value': 'media/nested.png'},
                  },
                ],
              },
              {
                'id': 'el-file',
                'type': 'Image',
                'source': {'kind': 'file', 'value': '/plain.png'},
              },
            ],
          },
        ],
        'editor': {
          'media': [
            {
              'id': 'media-1',
              'name': 'orphan.png',
              'kind': 'image',
              'source': {'kind': 'bundle', 'value': 'media/orphan.png'},
            },
          ],
        },
      });
      expect(referencedBundleValues(document), {
        'media/bed.mp3',
        'media/pop.wav',
        'media/b-roll.mp4',
        'media/poster.png',
        'media/nested.png',
      });
    });

    test('a plain deck references nothing', () {
      expect(referencedBundleValues(EditorDocument.fromJson(_deck())), isEmpty);
    });
  });

  group('MediaPick metadata', () {
    test('equality covers the audio flag and the import metadata', () {
      const a = MediaPick(
        source: {'kind': 'file', 'value': '/x.mp3'},
        isVideo: false,
        isAudio: true,
        name: 'x.mp3',
        sizeBytes: 5,
      );
      const b = MediaPick(
        source: {'kind': 'file', 'value': '/x.mp3'},
        isVideo: false,
        isAudio: true,
        name: 'x.mp3',
        sizeBytes: 5,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(const MediaPick(source: {'kind': 'file', 'value': '/x.mp3'}, isVideo: false)),
      );
    });
  });
}
