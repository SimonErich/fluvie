import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/speaker/sync_channel_stub.dart'
    if (dart.library.js_interop) 'package:fluvie_presenter/src/speaker/sync_channel_web.dart';
import 'package:fluvie_presenter/src/speaker/sync_message.dart';

/// The pipe between the presenting window and the speaker window.
///
/// Community multi-window setups give each window its own engine and
/// isolate, so nothing is shared but this channel: each end broadcasts its
/// position and applies what arrives. The web implementation rides a
/// `BroadcastChannel`; tests use an in-memory pair; platforms without a
/// transport report `null` from the provider and the presenter falls back
/// to single-window behavior.
abstract interface class PresentationSyncChannel {
  /// Sends [message] to the other window. Dropped when nobody listens.
  void send(SyncMessage message);

  /// The messages arriving from the other window.
  Stream<SyncMessage> get messages;

  /// Releases the transport.
  void close();
}

/// The platform's window-sync channel, or `null` where windows cannot talk
/// (no transport on this platform).
final presentationSyncChannelProvider = Provider<PresentationSyncChannel?>((ref) {
  final channel = createSyncChannel();
  ref.onDispose(() => channel?.close());
  return channel;
});
