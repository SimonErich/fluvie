import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';

/// A carrier that declares only a media source (no snapshot).
class _MediaOnlyCarrier implements MediaCarrier {
  @override
  MediaSource? get mediaSource => const MediaSource.asset('a.png');
  @override
  SnapshotSource? get snapshotSource => null;
}

/// A carrier that declares only a snapshot source (no media).
class _SnapshotOnlyCarrier implements MediaCarrier {
  @override
  MediaSource? get mediaSource => null;
  @override
  SnapshotSource? get snapshotSource => const SnapshotSource.mermaid('graph TD; A-->B');
}

/// A bare carrier declaring neither (the default `snapshotSource` is null).
class _BareCarrier implements MediaCarrier {
  @override
  MediaSource? get mediaSource => null;
  @override
  SnapshotSource? get snapshotSource => null;
}

void main() {
  group('MediaCarrier snapshotSource', () {
    test('a media-only carrier declares no snapshot', () {
      expect(_MediaOnlyCarrier().snapshotSource, isNull);
      expect(_MediaOnlyCarrier().mediaSource, isNotNull);
    });

    test('a snapshot-only carrier declares its snapshot and no media', () {
      final carrier = _SnapshotOnlyCarrier();
      expect(carrier.snapshotSource, isA<SnapshotSource>());
      expect(carrier.mediaSource, isNull);
    });

    test('a bare carrier declares neither', () {
      expect(_BareCarrier().mediaSource, isNull);
      expect(_BareCarrier().snapshotSource, isNull);
    });
  });
}
