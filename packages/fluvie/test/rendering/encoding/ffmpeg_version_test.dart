import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_version.dart';

void main() {
  group('FfmpegVersion.parse', () {
    test('parses a plain release banner: "ffmpeg version 6.0"', () {
      final version = FfmpegVersion.parse('ffmpeg version 6.0 Copyright (c) 2000-2023');
      expect(version, isNotNull);
      expect(version!.major, 6);
      expect(version.minor, 0);
      expect(version.meetsFloor, isTrue);
    });

    test('parses a distro-suffixed version: "6.1.1-3ubuntu5"', () {
      final version = FfmpegVersion.parse('ffmpeg version 6.1.1-3ubuntu5 Copyright (c) 2000-2023');
      expect(version, isNotNull);
      expect(version!.major, 6);
      expect(version.minor, 1);
      expect(version.meetsFloor, isTrue);
    });

    test('parses a tag-prefixed version: "n7.0"', () {
      final version = FfmpegVersion.parse('ffmpeg version n7.0 Copyright (c) 2000-2024');
      expect(version, isNotNull);
      expect(version!.major, 7);
      expect(version.minor, 0);
      expect(version.meetsFloor, isTrue);
    });

    test('parses but fails the floor for "5.1.4"', () {
      final version = FfmpegVersion.parse('ffmpeg version 5.1.4-0+deb12u1');
      expect(version, isNotNull);
      expect(version!.major, 5);
      expect(version.minor, 1);
      expect(version.meetsFloor, isFalse);
    });

    test('returns null for garbage', () {
      expect(FfmpegVersion.parse('not a version banner at all'), isNull);
      expect(FfmpegVersion.parse('ffmpeg version N-113007-g8d24a28d06'), isNull);
    });

    test('rejects a git-master banner whose only dotted pair is the gcc line', () {
      const banner =
          'ffmpeg version N-113007-g8d24a28d06 Copyright (c) 2000-2023 the FFmpeg developers\n'
          'built with gcc 12.2.0 (Debian 12.2.0-14)';
      expect(FfmpegVersion.parse(banner), isNull);
    });

    test('returns null for the empty string', () {
      expect(FfmpegVersion.parse(''), isNull);
    });
  });

  group('FfmpegVersion.meetsFloor', () {
    test('passes exactly at the 6.0 boundary', () {
      expect(const FfmpegVersion(6, 0).meetsFloor, isTrue);
    });

    test('fails just below the boundary', () {
      expect(const FfmpegVersion(5, 9).meetsFloor, isFalse);
    });

    test('passes well above the boundary (8.0, the local binary)', () {
      expect(const FfmpegVersion(8, 0).meetsFloor, isTrue);
    });
  });

  test('toString is the dotted pair, for error messages', () {
    expect(const FfmpegVersion(6, 1).toString(), '6.1');
  });
}
