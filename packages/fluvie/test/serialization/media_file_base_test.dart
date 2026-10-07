import 'package:flutter/widgets.dart' show Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/media_file_base.dart';

Widget _elem(Map<String, Object?> json) {
  final table = AnchorTable();
  return ElementSpec.fromJson(json, table).build(table);
}

void main() {
  tearDown(() => MediaFileBase.current = null);

  group('resolvePath', () {
    test('passes every value through outside any scope', () {
      expect(MediaFileBase.resolvePath('media/intro.mp4'), 'media/intro.mp4');
      expect(MediaFileBase.resolvePath('/abs/intro.mp4'), '/abs/intro.mp4');
    });

    test('joins a relative value onto the current base', () {
      MediaFileBase.current = '/decks/launch';
      expect(MediaFileBase.resolvePath('media/intro.mp4'), '/decks/launch/media/intro.mp4');
    });

    test('a base with a trailing slash joins without doubling it', () {
      MediaFileBase.current = '/decks/launch/';
      expect(MediaFileBase.resolvePath('media/intro.mp4'), '/decks/launch/media/intro.mp4');
    });

    test('absolute values stay verbatim under a scope', () {
      MediaFileBase.current = '/decks/launch';
      expect(MediaFileBase.resolvePath('/elsewhere/intro.mp4'), '/elsewhere/intro.mp4');
      expect(MediaFileBase.resolvePath(r'C:\media\intro.mp4'), r'C:\media\intro.mp4');
      expect(MediaFileBase.resolvePath('D:/media/intro.mp4'), 'D:/media/intro.mp4');
      expect(MediaFileBase.resolvePath(r'\\server\share\intro.mp4'), r'\\server\share\intro.mp4');
    });
  });

  group('isAbsolute', () {
    test('a POSIX root, a Windows drive, and a UNC share are absolute', () {
      expect(MediaFileBase.isAbsolute('/abs/intro.mp4'), isTrue);
      expect(MediaFileBase.isAbsolute(r'C:\media\intro.mp4'), isTrue);
      expect(MediaFileBase.isAbsolute('D:/media/intro.mp4'), isTrue);
      expect(MediaFileBase.isAbsolute(r'\\server\share\intro.mp4'), isTrue);
    });

    test('a document-relative value is not absolute', () {
      expect(MediaFileBase.isAbsolute('media/intro.mp4'), isFalse);
      expect(MediaFileBase.isAbsolute('intro.mp4'), isFalse);
    });
  });

  group('join', () {
    test('joins a value onto a base with a single separator', () {
      expect(
        MediaFileBase.join('/decks/launch', 'media/intro.mp4'),
        '/decks/launch/media/intro.mp4',
      );
    });

    test('a base with a trailing slash does not double the separator', () {
      expect(
        MediaFileBase.join('/decks/launch/', 'media/intro.mp4'),
        '/decks/launch/media/intro.mp4',
      );
    });
  });

  group('resolve', () {
    test('scopes one build and restores the previous base on exit', () {
      MediaFileBase.current = '/outer';
      final resolved = MediaFileBase.resolve(
        '/decks/launch',
        () => MediaFileBase.resolvePath('a.png'),
      );
      expect(resolved, '/decks/launch/a.png');
      expect(MediaFileBase.current, '/outer');
    });

    test('restores the previous base when the build throws', () {
      MediaFileBase.current = '/outer';
      expect(
        () => MediaFileBase.resolve('/decks/launch', () => throw StateError('boom')),
        throwsStateError,
      );
      expect(MediaFileBase.current, '/outer');
    });

    test('a null scope builds without a base', () {
      MediaFileBase.current = '/outer';
      final resolved = MediaFileBase.resolve(null, () => MediaFileBase.resolvePath('a.png'));
      expect(resolved, 'a.png');
    });
  });

  group('the element codec', () {
    test('resolves relative image, clip, and poster file values against the base', () {
      MediaFileBase.current = '/decks/launch';
      final image =
          _elem(const {
                'type': 'Image',
                'source': {'kind': 'file', 'value': 'media/photo.png'},
              })
              as Image;
      expect(image.source, const MediaSource.file('/decks/launch/media/photo.png'));
      final clip =
          _elem(const {
                'type': 'Clip',
                'source': {'kind': 'file', 'value': 'media/broll.mp4'},
                'poster': {'kind': 'file', 'value': 'media/poster.png'},
              })
              as Clip;
      expect(clip.source, const MediaSource.file('/decks/launch/media/broll.mp4'));
      expect(clip.poster, const MediaSource.file('/decks/launch/media/poster.png'));
    });

    test('keeps absolute file values verbatim under the base', () {
      MediaFileBase.current = '/decks/launch';
      final image =
          _elem(const {
                'type': 'Image',
                'source': {'kind': 'file', 'value': '/tmp/a.png'},
              })
              as Image;
      expect(image.source, const MediaSource.file('/tmp/a.png'));
    });

    test('keeps relative file values verbatim outside any scope', () {
      final image =
          _elem(const {
                'type': 'Image',
                'source': {'kind': 'file', 'value': 'media/photo.png'},
              })
              as Image;
      expect(image.source, const MediaSource.file('media/photo.png'));
    });
  });
}
