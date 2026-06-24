import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_generative_exception.dart';
import 'package:fluvie/src/core/media/generative_source.dart';
import 'package:fluvie/src/rendering/no_generative_resolver.dart';

void main() {
  const resolver = NoGenerativeResolver();
  const source = GenerativeSource.image(providerId: 'flux', prompt: 'a cat');

  test('generateAll over an empty set is a no-op', () {
    expect(resolver.generateAll(const []), completes);
  });

  test('generateAll with a source throws and names the install fix', () async {
    await expectLater(
      resolver.generateAll(const [source]),
      throwsA(
        isA<FluvieGenerativeException>().having(
          (e) => e.message,
          'message',
          allOf(contains('No generative backend'), contains('fluvie_ai')),
        ),
      ),
    );
  });

  test('mediaFor / audioFor / metaFor throw FluvieGenerativeException', () {
    expect(() => resolver.mediaFor(source), throwsA(isA<FluvieGenerativeException>()));
    expect(() => resolver.audioFor(source), throwsA(isA<FluvieGenerativeException>()));
    expect(() => resolver.metaFor(source), throwsA(isA<FluvieGenerativeException>()));
  });
}
