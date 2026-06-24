import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/generative.dart';

void main() {
  test('providerIdFor maps the known provider strings the widgets emit', () {
    expect(providerIdFor('flux'), ProviderId.flux);
    expect(providerIdFor('gemini'), ProviderId.gemini);
    expect(providerIdFor('openai'), ProviderId.openai);
    expect(providerIdFor('veo'), ProviderId.veo);
    expect(providerIdFor('suno'), ProviderId.suno);
    expect(providerIdFor('elevenlabs'), ProviderId.elevenLabs);
  });

  test('providerIdFor throws a FluvieGenerativeException for an unknown provider', () {
    expect(
      () => providerIdFor('nope'),
      throwsA(
        isA<FluvieGenerativeException>().having((e) => e.message, 'message', contains('nope')),
      ),
    );
  });
}
