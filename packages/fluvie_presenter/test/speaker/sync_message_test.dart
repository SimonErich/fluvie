import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

void main() {
  test('a position update round-trips through JSON', () {
    const message = PositionUpdate(PresentationPosition(3, 2));
    final decoded = SyncMessage.fromJson(message.toJson());
    expect(decoded, message);
    expect(decoded.hashCode, message.hashCode);
  });

  test('a navigation request round-trips through JSON', () {
    const message = NavigationRequest.next();
    expect(SyncMessage.fromJson(message.toJson()), message);
    const jump = NavigationRequest.jump(PresentationPosition(1, 0));
    expect(SyncMessage.fromJson(jump.toJson()), jump);
    const back = NavigationRequest.back();
    expect(SyncMessage.fromJson(back.toJson()), back);
    expect(back, isNot(message));
  });

  test('unknown payloads are rejected with a FormatException', () {
    expect(() => SyncMessage.fromJson(const {'type': 'dance'}), throwsFormatException);
    expect(() => SyncMessage.fromJson(const {}), throwsFormatException);
  });

  test('a jump request must carry its target', () {
    expect(
      () => SyncMessage.fromJson(const {'type': 'navigate', 'action': 'jump'}),
      throwsFormatException,
    );
  });
}
