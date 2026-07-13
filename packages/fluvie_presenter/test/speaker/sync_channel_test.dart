import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

import 'fake_sync_channel.dart';

void main() {
  test('a position change on one end arrives on the other', () async {
    final pair = FakeSyncChannelPair();
    final received = <SyncMessage>[];
    pair.speaker.messages.listen(received.add);
    pair.main.send(const PositionUpdate(PresentationPosition(2, 1)));
    await Future<void>.delayed(Duration.zero);
    expect(received, const [PositionUpdate(PresentationPosition(2, 1))]);
    pair.main.close();
    pair.speaker.close();
  });

  test('a navigation request round-trips from the speaker end', () async {
    final pair = FakeSyncChannelPair();
    final onMain = <SyncMessage>[];
    pair.main.messages.listen(onMain.add);
    pair.speaker.send(const NavigationRequest.next());
    pair.speaker.send(const NavigationRequest.jump(PresentationPosition(0, 2)));
    await Future<void>.delayed(Duration.zero);
    expect(onMain, const [
      NavigationRequest.next(),
      NavigationRequest.jump(PresentationPosition(0, 2)),
    ]);
    pair.main.close();
    pair.speaker.close();
  });

  test('sending after close is dropped, never thrown', () async {
    final pair = FakeSyncChannelPair();
    pair.speaker.close();
    pair.main.send(const NavigationRequest.back());
    await Future<void>.delayed(Duration.zero);
    pair.main.close();
  });
}
