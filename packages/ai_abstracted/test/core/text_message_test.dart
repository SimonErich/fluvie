import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

void main() {
  group('TextMessage', () {
    test('user constructor sets the user role', () {
      const message = TextMessage.user('hi');
      expect(message.role, TextRole.user);
      expect(message.text, 'hi');
    });

    test('assistant constructor sets the assistant role', () {
      const message = TextMessage.assistant('hello');
      expect(message.role, TextRole.assistant);
      expect(message.text, 'hello');
    });

    test('value equality and hashCode by role and text', () {
      const a = TextMessage.user('hi');
      const b = TextMessage.user('hi');
      const c = TextMessage.assistant('hi');
      const d = TextMessage.user('bye');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(d));
      expect(a == a, isTrue);
      expect(a == Object(), isFalse);
    });

    test('toString carries role and text', () {
      expect(const TextMessage.user('hi').toString(), contains('user'));
      expect(const TextMessage.user('hi').toString(), contains('hi'));
    });
  });
}
