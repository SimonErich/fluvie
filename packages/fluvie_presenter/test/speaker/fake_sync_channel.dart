import 'dart:async';

import 'package:fluvie_presenter/fluvie_presenter.dart';

/// Two in-memory channel ends wired to each other — what a BroadcastChannel
/// pair does across windows, without a browser.
final class FakeSyncChannelPair {
  /// Creates the linked pair.
  FakeSyncChannelPair() {
    main = FakeSyncEnd();
    speaker = FakeSyncEnd();
    main._peer = speaker;
    speaker._peer = main;
  }

  /// The presenting window's end.
  late final FakeSyncEnd main;

  /// The speaker window's end.
  late final FakeSyncEnd speaker;
}

/// One end of the fake pair.
final class FakeSyncEnd implements PresentationSyncChannel {
  final StreamController<SyncMessage> _incoming = StreamController.broadcast();
  late FakeSyncEnd _peer;
  bool closed = false;

  @override
  Stream<SyncMessage> get messages => _incoming.stream;

  @override
  void send(SyncMessage message) {
    if (closed || _peer.closed) return;
    // Encode and decode like the real transport, so only JSON-safe messages
    // survive the fake too.
    _peer._incoming.add(SyncMessage.fromJson(message.toJson()));
  }

  @override
  void close() {
    closed = true;
    unawaited(_incoming.close());
  }
}
