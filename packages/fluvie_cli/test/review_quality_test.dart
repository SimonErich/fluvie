import 'package:fluvie_cli/src/review_quality.dart';
import 'package:test/test.dart';

void main() {
  test('audio review reports measured silent intervals and near-full-scale peak', () {
    final quality = parseAudioQuality('''
[silencedetect] silence_start: 1.25
[silencedetect] silence_end: 3.75 | silence_duration: 2.5
[astats] Peak level dB: -0.01
''', fps: 30);
    final findings = (quality['findings']! as List).cast<Map<String, Object?>>();
    expect(findings.map((v) => v['code']), ['audio_silence', 'audio_peak']);
    expect(findings.first['startFrame'], 37);
    expect(findings.first['endFrame'], 113);
    expect(findings.last['message'], contains('risk'));
  });

  test('intentional exceptions are retained with their reason and strict mode respects them', () {
    final quality = evaluateReviewQuality(
      {
        'findings': [
          {'code': 'text_overflow', 'severity': 'warning'},
          {'code': 'audio_silence', 'severity': 'warning'},
        ],
      },
      allowed: const {'audio_silence'},
      strict: true,
    );
    expect(quality['ok'], isFalse);
    final findings = (quality['findings']! as List).cast<Map<String, Object?>>();
    expect(findings.last['allowed'], isTrue);
    expect(
      evaluateReviewQuality(
        {
          'findings': [findings.last],
        },
        allowed: const {'audio_silence'},
        strict: true,
      )['ok'],
      isTrue,
    );
  });

  test('missing measured audio statistics do not count as a successful check', () {
    expect(parseAudioQuality('no statistics', fps: 30)['checked'], isFalse);
    expect(parseAudioQuality('Peak level dB: -inf', fps: 30)['checked'], isTrue);
  });
  test('strict quality rejects failed measurements but permits absent audio', () {
    final unavailable = evaluateReviewQuality({
      'findings': <Object?>[],
      'audio': {'checked': false, 'error': 'FFmpeg failed'},
    }, strict: true);
    expect(unavailable['ok'], isFalse);
    expect(unavailable['checksComplete'], isFalse);
    expect(
      evaluateReviewQuality({
        'findings': <Object?>[],
        'audio': {'checked': false, 'applicable': false, 'reason': 'No audio stream'},
      }, strict: true)['ok'],
      isTrue,
    );
  });
}
