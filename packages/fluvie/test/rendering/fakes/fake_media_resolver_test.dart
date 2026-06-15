import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';

import 'fake_media_resolver.dart';

/// A stub service the fake's canned snapshot path never actually invokes.
class _UnusedSnapshotService implements SnapshotService {
  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async =>
      SnapshotRaster(bytes: Uint8List(0), contentHash: 'x', width: 1, height: 1);
}

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 2),
    ui.Paint()..color = const ui.Color(0xFF112233),
  );
  return recorder.endRecording().toImage(2, 2);
}

void main() {
  const logo = MediaSource.asset('logo.png');
  final clip = MediaSource.network(Uri.parse('https://example.com/clip.mp4'));
  final logoMedia = (bytes: Uint8List.fromList([1, 2, 3]), contentHash: 'abc123');

  group('FakeMediaResolver', () {
    test('round-trips canned media after preResolveAll', () async {
      final resolver = FakeMediaResolver({logo: logoMedia});

      await resolver.preResolveAll([logo]);
      final resolved = resolver.resolvedFor(logo);

      expect(resolved.bytes, [1, 2, 3]);
      expect(resolved.contentHash, 'abc123');
    });

    test('resolvedFor before preResolveAll throws StateError (pass ordering)', () {
      final resolver = FakeMediaResolver({logo: logoMedia});

      expect(
        () => resolver.resolvedFor(logo),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('preResolveAll')),
        ),
      );
    });

    test('decodedImageFor before preResolveAll throws StateError (pass ordering)', () async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final resolver = FakeMediaResolver({logo: logoMedia}, images: {logo: image});

      expect(
        () => resolver.decodedImageFor(logo),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('preResolveAll')),
        ),
      );
    });

    test('decodedImageFor returns the canned image after preResolveAll', () async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final resolver = FakeMediaResolver({logo: logoMedia}, images: {logo: image});

      await resolver.preResolveAll([logo]);

      expect(resolver.decodedImageFor(logo), same(image));
    });

    test('preResolveAll of an un-canned source throws a typed error', () async {
      final resolver = FakeMediaResolver({logo: logoMedia});

      await expectLater(
        () => resolver.preResolveAll([clip]),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('$clip')),
        ),
      );
    });

    test('resolvedFor of an unresolved source throws a typed error', () async {
      final resolver = FakeMediaResolver({logo: logoMedia});

      await resolver.preResolveAll([logo]);

      expect(
        () => resolver.resolvedFor(clip),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('$clip')),
        ),
      );
    });

    test('decodedImageFor of a non-image source throws a typed error', () async {
      final resolver = FakeMediaResolver({logo: logoMedia});

      await resolver.preResolveAll([logo]);

      expect(
        () => resolver.decodedImageFor(logo),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('$logo')),
        ),
      );
    });
  });

  group('FakeMediaResolver snapshots', () {
    const mermaid = SnapshotSource.mermaid('graph TD; A-->B');

    test('decodedSnapshotFor returns the canned image after preResolveSnapshots', () async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final resolver = FakeMediaResolver(const {}, snapshots: {mermaid: image});

      await resolver.preResolveSnapshots([mermaid], _UnusedSnapshotService());

      expect(resolver.decodedSnapshotFor(mermaid), same(image));
    });

    test('decodedSnapshotFor before preResolveSnapshots throws StateError', () async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final resolver = FakeMediaResolver(const {}, snapshots: {mermaid: image});

      expect(
        () => resolver.decodedSnapshotFor(mermaid),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('preResolveAll')),
        ),
      );
    });

    test('preResolveSnapshots of an un-canned source throws a typed error', () async {
      final resolver = FakeMediaResolver(const {});

      await expectLater(
        () => resolver.preResolveSnapshots([mermaid], _UnusedSnapshotService()),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('mermaid')),
        ),
      );
    });

    test('decodedSnapshotFor of an unresolved source throws a typed error', () async {
      final image = await _solidImage();
      addTearDown(image.dispose);
      final resolver = FakeMediaResolver(const {}, snapshots: {mermaid: image});

      await resolver.preResolveSnapshots([mermaid], _UnusedSnapshotService());

      const other = SnapshotSource.mermaid('graph LR; X-->Y');
      expect(
        () => resolver.decodedSnapshotFor(other),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('mermaid')),
        ),
      );
    });

    group('audio', () {
      const song = AudioSource.asset('audio/song.mp3');

      test('materializedAudioPathFor serves the canned path after pre-resolve', () async {
        final resolver = FakeMediaResolver(const {}, audioPaths: {song: '/tmp/song.mp3'});
        await resolver.preResolveAudio(const [song]);
        expect(resolver.materializedAudioPathFor(song), '/tmp/song.mp3');
      });

      test('materializedAudioPathFor before pre-resolve is a StateError', () {
        final resolver = FakeMediaResolver(const {}, audioPaths: {song: '/tmp/song.mp3'});
        expect(() => resolver.materializedAudioPathFor(song), throwsStateError);
      });

      test('preResolveAudio throws naming an un-canned source', () {
        final resolver = FakeMediaResolver(const {});
        expect(
          () => resolver.preResolveAudio(const [song]),
          throwsA(
            isA<FluvieRenderException>().having((e) => e.message, 'message', contains('song.mp3')),
          ),
        );
      });
    });
  });
}
