import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_example/snippets/audio_analysis_snippets.dart';

void main() {
  test(
    'documented analysis services observe cancellation before touching a source or executable',
    () async {
      final cancellation = RenderCancellation()..cancel();
      final services = boundedDesktopAnalysis(cancellation);
      const source = FileAudioSource('/does-not-exist/unused.wav');
      final cancelled = throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'preparation cancellation',
          'Media operation cancelled',
        ),
      );
      await expectLater(services.beats.detect(source, fps: 30, totalFrames: 30), cancelled);
      await expectLater(services.bands.analyze(source, fps: 30, totalFrames: 30), cancelled);
    },
  );
}
