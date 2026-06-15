import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/rendering/encoding/export_args.dart';

void main() {
  group('validateFfmpegName', () {
    test('accepts a bare file name', () {
      expect(() => validateFfmpegName('out.gif', 'name'), returnsNormally);
    });

    test('rejects an empty name', () {
      expect(() => validateFfmpegName('', 'name'), throwsArgumentError);
    });

    test('rejects a leading dash (flag injection)', () {
      expect(() => validateFfmpegName('-out.gif', 'name'), throwsArgumentError);
    });

    test('rejects path separators and traversal', () {
      expect(() => validateFfmpegName('../evil.gif', 'name'), throwsArgumentError);
      expect(() => validateFfmpegName('dir/out.gif', 'name'), throwsArgumentError);
      expect(() => validateFfmpegName(r'dir\out.gif', 'name'), throwsArgumentError);
    });

    test('rejects a bare percent without the image pattern flag', () {
      expect(() => validateFfmpegName('frame_%06d.png', 'name'), throwsArgumentError);
      expect(() => validateFfmpegName('out%.png', 'name'), throwsArgumentError);
    });

    group('image pattern names (allowImagePattern: true)', () {
      test('accepts exactly one %0Nd token', () {
        expect(
          () => validateFfmpegName('frame_%06d.png', 'name', allowImagePattern: true),
          returnsNormally,
        );
        expect(
          () => validateFfmpegName('f_%04d.png', 'name', allowImagePattern: true),
          returnsNormally,
        );
      });

      test('rejects two percent tokens', () {
        expect(
          () => validateFfmpegName('frame_%06d_%02d.png', 'name', allowImagePattern: true),
          throwsArgumentError,
        );
      });

      test('rejects a bare percent that is not a %0Nd token', () {
        expect(
          () => validateFfmpegName('frame_%.png', 'name', allowImagePattern: true),
          throwsArgumentError,
        );
        expect(
          () => validateFfmpegName('frame_%d.png', 'name', allowImagePattern: true),
          throwsArgumentError,
        );
        expect(
          () => validateFfmpegName('frame_%6d.png', 'name', allowImagePattern: true),
          throwsArgumentError,
        );
      });

      test('still rejects traversal and leading dash with the pattern flag', () {
        expect(
          () => validateFfmpegName('../frame_%06d.png', 'name', allowImagePattern: true),
          throwsArgumentError,
        );
        expect(
          () => validateFfmpegName('-frame_%06d.png', 'name', allowImagePattern: true),
          throwsArgumentError,
        );
      });
    });
  });

  group('gifFilterComplex', () {
    test('emits the single-graph two-pass palette graph', () {
      expect(
        gifFilterComplex(fps: 15),
        'fps=15,scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=lanczos,split[s0][s1];'
        '[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer',
      );
    });

    test('threads the sampled fps into the graph', () {
      expect(gifFilterComplex(fps: 24), startsWith('fps=24,'));
    });

    test('rejects a non-positive fps', () {
      expect(() => gifFilterComplex(fps: 0), throwsArgumentError);
      expect(() => gifFilterComplex(fps: -5), throwsArgumentError);
    });
  });

  group('gifOutputArgs', () {
    test('emits the validated -filter_complex, -an, output array', () {
      expect(gifOutputArgs(name: 'out.gif', fps: 15), [
        '-filter_complex',
        gifFilterComplex(fps: 15),
        '-an',
      ]);
    });

    test('rejects an unsafe output name', () {
      expect(() => gifOutputArgs(name: '../out.gif', fps: 15), throwsArgumentError);
      expect(() => gifOutputArgs(name: '-out.gif', fps: 15), throwsArgumentError);
    });
  });

  group('imageSequenceOutputArgs', () {
    test('emits -c:v png -f image2 for a PNG sequence', () {
      expect(imageSequenceOutputArgs(name: 'frame_%06d.png', format: ImageFormat.png), [
        '-c:v',
        'png',
        '-f',
        'image2',
      ]);
    });

    test('validates the pattern name allowing exactly one %0Nd token', () {
      expect(
        () => imageSequenceOutputArgs(name: 'frame_%06d.png', format: ImageFormat.png),
        returnsNormally,
      );
      expect(
        () => imageSequenceOutputArgs(name: 'frame_%06d_%02d.png', format: ImageFormat.png),
        throwsArgumentError,
      );
      expect(
        () => imageSequenceOutputArgs(name: '../frame_%06d.png', format: ImageFormat.png),
        throwsArgumentError,
      );
      expect(
        () => imageSequenceOutputArgs(name: '-frame_%06d.png', format: ImageFormat.png),
        throwsArgumentError,
      );
      expect(
        () => imageSequenceOutputArgs(name: 'frame_%.png', format: ImageFormat.png),
        throwsArgumentError,
      );
    });
  });

  group('imageSequenceName', () {
    test('is the default 6-digit png pattern', () {
      expect(imageSequenceName(ImageFormat.png), 'frame_%06d.png');
    });
  });

  group('transparentOutputArgs', () {
    test('emits VP9 with a yuva420p alpha plane and -auto-alt-ref 0', () {
      expect(transparentOutputArgs(name: 'out.webm'), [
        '-c:v',
        'libvpx-vp9',
        '-pix_fmt',
        'yuva420p',
        '-auto-alt-ref',
        '0',
        '-an',
      ]);
    });

    test('keeps an alpha-capable pixel format (never forces yuv420p)', () {
      expect(transparentOutputArgs(name: 'out.webm'), isNot(contains('yuv420p')));
      expect(transparentOutputArgs(name: 'out.webm'), contains('yuva420p'));
    });

    test('rejects an unsafe output name', () {
      expect(() => transparentOutputArgs(name: '../out.webm'), throwsArgumentError);
      expect(() => transparentOutputArgs(name: '-out.webm'), throwsArgumentError);
    });
  });

  group('posterFilter', () {
    test('selects exactly one frame by index', () {
      expect(posterFilter(42), r'select=eq(n\,42)');
    });

    test('rejects a negative frame index', () {
      expect(() => posterFilter(-1), throwsArgumentError);
    });
  });

  group('posterOutputArgs', () {
    test('emits the validated select filter, -vframes 1, -an, poster name', () {
      expect(posterOutputArgs(name: 'poster.png', frameIndex: 12), [
        '-vf',
        r'select=eq(n\,12)',
        '-vframes',
        '1',
        '-an',
        'poster.png',
      ]);
    });

    test('rejects an unsafe poster name', () {
      expect(() => posterOutputArgs(name: '../poster.png', frameIndex: 0), throwsArgumentError);
      expect(() => posterOutputArgs(name: '-poster.png', frameIndex: 0), throwsArgumentError);
    });
  });

  group('exportOutputName', () {
    test('picks the per-mode default output name', () {
      expect(exportOutputName(const Export.mp4()), 'out.mp4');
      expect(exportOutputName(const Export.gif()), 'out.gif');
      expect(exportOutputName(const Export.imageSequence()), 'frame_%06d.png');
      expect(exportOutputName(const Export.transparent()), 'out.webm');
      expect(exportOutputName(null), 'out.mp4');
    });
  });
}
