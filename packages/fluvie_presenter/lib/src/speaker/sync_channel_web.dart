import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:fluvie_presenter/src/speaker/presentation_sync_channel.dart';
import 'package:fluvie_presenter/src/speaker/sync_message.dart';
import 'package:web/web.dart' as web;

/// Creates the web channel over a named `BroadcastChannel`.
PresentationSyncChannel? createSyncChannel() => WebSyncChannel();

// coverage:ignore-start browser bindings the VM coverage run never loads this library and the mapping onto BroadcastChannel is direct

/// The web transport: same-origin windows join the shared
/// `fluvie_presenter_sync` broadcast channel. Messages travel as JSON
/// strings, which sidesteps structured-clone typing entirely.
final class WebSyncChannel implements PresentationSyncChannel {
  /// Opens the shared channel.
  WebSyncChannel() {
    _channel.onmessage = ((web.MessageEvent event) {
      final data = event.data;
      if (data == null || !data.isA<JSString>()) return;
      _incoming.add(
        SyncMessage.fromJson(
          jsonDecode((data as JSString).toDart) as Map<String, Object?>,
        ),
      );
    }).toJS;
  }

  final web.BroadcastChannel _channel = web.BroadcastChannel('fluvie_presenter_sync');
  final StreamController<SyncMessage> _incoming = StreamController.broadcast();

  @override
  Stream<SyncMessage> get messages => _incoming.stream;

  @override
  void send(SyncMessage message) => _channel.postMessage(jsonEncode(message.toJson()).toJS);

  @override
  void close() {
    _channel.close();
    unawaited(_incoming.close());
  }
}

// coverage:ignore-end
