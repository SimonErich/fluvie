import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('AiException', () {
    test('is an Exception and exposes its fields', () {
      final cause = StateError('boom');
      final exception = AiException(
        'bad',
        provider: 'openai',
        statusCode: 500,
        cause: cause,
      );
      expect(exception, isA<Exception>());
      expect(exception.message, 'bad');
      expect(exception.provider, 'openai');
      expect(exception.statusCode, 500);
      expect(exception.cause, same(cause));
    });

    test('toString includes the label, provider, status and message', () {
      final exception = AiException('bad', provider: 'openai', statusCode: 500);
      final text = exception.toString();
      expect(text, contains('AiException'));
      expect(text, contains('openai'));
      expect(text, contains('500'));
      expect(text, contains('bad'));
    });

    test('toString omits the status when null', () {
      expect(AiException('bad', provider: 'openai').toString(), isNot(contains('null')));
    });
  });

  group('subclasses', () {
    test('all extend AiException and pass fields through', () {
      final exceptions = <AiException>[
        AiAuthException('a', provider: 'p', statusCode: 401),
        AiRateLimitException('a', provider: 'p', statusCode: 429),
        AiInvalidRequestException('a', provider: 'p', statusCode: 400),
        AiTransientException('a', provider: 'p', statusCode: 503),
        AiResponseException('a', provider: 'p'),
        AiTimeoutException('a', provider: 'p'),
      ];
      for (final exception in exceptions) {
        expect(exception, isA<AiException>());
        expect(exception.provider, 'p');
        expect(exception.message, 'a');
      }
    });

    test('each subclass has a distinct toString label', () {
      expect(AiAuthException('a', provider: 'p').toString(), contains('AiAuthException'));
      expect(AiRateLimitException('a', provider: 'p').toString(), contains('AiRateLimitException'));
      expect(
        AiInvalidRequestException('a', provider: 'p').toString(),
        contains('AiInvalidRequestException'),
      );
      expect(
        AiTransientException('a', provider: 'p').toString(),
        contains('AiTransientException'),
      );
      expect(
        AiResponseException('a', provider: 'p').toString(),
        contains('AiResponseException'),
      );
      expect(AiTimeoutException('a', provider: 'p').toString(), contains('AiTimeoutException'));
    });

    test('rate limit carries an optional retryAfter', () {
      const retry = Duration(seconds: 3);
      final exception = AiRateLimitException('a', provider: 'p', retryAfter: retry);
      expect(exception.retryAfter, retry);
      expect(AiRateLimitException('a', provider: 'p').retryAfter, isNull);
    });
  });
}
