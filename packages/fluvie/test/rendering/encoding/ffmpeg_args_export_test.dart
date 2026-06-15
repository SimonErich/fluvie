import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_args.dart';

/// The bitexact determinism quartet plus the single-thread flag, present in
/// every encode mode.
const _quartet = [
  '-fflags',
  '+bitexact',
  '-flags:v',
  '+bitexact',
  '-map_metadata',
  '-1',
  '-threads',
  '1',
];

FfmpegArgsBuilder _rawInput() =>
    FfmpegArgsBuilder()..addRawVideoInput(name: 'frames.rgba', width: 320, height: 240, fps: 30);

void main() {
  group('setGifOutput', () {
    test('emits the palette filter_complex graph, -an, the quartet and the name', () {
      final args = (_rawInput()..setGifOutput(name: 'out.gif', fps: 15)).build();
      expect(args, contains('-filter_complex'));
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, startsWith('fps=15,'));
      expect(graph, contains('palettegen=stats_mode=diff'));
      expect(graph, contains('paletteuse=dither=bayer'));
      expect(args, contains('-an'));
      expect(args, isNot(contains('libx264')));
      final i = args.indexOf('-fflags');
      expect(args.sublist(i, i + 8), _quartet);
      expect(args.last, 'out.gif');
    });

    test('rejects an unsafe name and a second output', () {
      expect(
        () => _rawInput().setGifOutput(name: '../out.gif', fps: 15),
        throwsArgumentError,
      );
      final builder = _rawInput()..setGifOutput(name: 'out.gif', fps: 15);
      expect(
        () => builder.setGifOutput(name: 'other.gif', fps: 15),
        throwsStateError,
      );
    });
  });

  group('setImageSequenceOutput', () {
    test('emits -c:v png -f image2, -an, the quartet and the %0Nd pattern', () {
      final args =
          (_rawInput()
                ..setImageSequenceOutput(name: 'frame_%06d.png', format: ImageFormat.png, fps: 30))
              .build();
      expect(args, containsAllInOrder(<String>['-c:v', 'png', '-f', 'image2']));
      expect(args, contains('-an'));
      final i = args.indexOf('-fflags');
      expect(args.sublist(i, i + 8), _quartet);
      expect(args.last, 'frame_%06d.png');
    });

    test('rejects a pattern with two percent tokens', () {
      expect(
        () => _rawInput().setImageSequenceOutput(
          name: 'frame_%06d_%02d.png',
          format: ImageFormat.png,
          fps: 30,
        ),
        throwsArgumentError,
      );
    });
  });

  group('setTransparentOutput', () {
    test('emits VP9/yuva420p/-auto-alt-ref 0, -an, the quartet and the name', () {
      final args = (_rawInput()..setTransparentOutput(name: 'out.webm', fps: 30)).build();
      expect(
        args,
        containsAllInOrder(<String>[
          '-c:v',
          'libvpx-vp9',
          '-pix_fmt',
          'yuva420p',
          '-auto-alt-ref',
          '0',
        ]),
      );
      expect(args, contains('-an'));
      expect(args, isNot(contains('yuv420p')));
      final i = args.indexOf('-fflags');
      expect(args.sublist(i, i + 8), _quartet);
      expect(args.last, 'out.webm');
    });

    test('rejects an unsafe name', () {
      expect(
        () => _rawInput().setTransparentOutput(name: '-out.webm', fps: 30),
        throwsArgumentError,
      );
    });
  });

  group('setPosterOutput', () {
    test('emits the select filter, -vframes 1, -an, the quartet and the name', () {
      final args = (_rawInput()..setPosterOutput(name: 'poster.png', frameIndex: 12, fps: 30))
          .build();
      expect(args, containsAllInOrder(<String>['-vf', r'select=eq(n\,12)', '-vframes', '1']));
      expect(args, contains('-an'));
      final i = args.indexOf('-fflags');
      expect(args.sublist(i, i + 8), _quartet);
      expect(args.last, 'poster.png');
    });

    test('rejects a negative frame index and an unsafe name', () {
      expect(
        () => _rawInput().setPosterOutput(name: 'poster.png', frameIndex: -1, fps: 30),
        throwsArgumentError,
      );
      expect(
        () => _rawInput().setPosterOutput(name: '../poster.png', frameIndex: 0, fps: 30),
        throwsArgumentError,
      );
    });
  });

  test('every export mode keeps the bitexact quartet and -threads 1', () {
    final builders = <FfmpegArgsBuilder>[
      _rawInput()..setGifOutput(name: 'out.gif', fps: 15),
      _rawInput()..setImageSequenceOutput(name: 'f_%06d.png', format: ImageFormat.png, fps: 30),
      _rawInput()..setTransparentOutput(name: 'out.webm', fps: 30),
      _rawInput()..setPosterOutput(name: 'poster.png', frameIndex: 0, fps: 30),
    ];
    for (final builder in builders) {
      final args = builder.build();
      final i = args.indexOf('-fflags');
      expect(args.sublist(i, i + 8), _quartet);
      expect(args, isNot(contains('-y')));
    }
  });
}
