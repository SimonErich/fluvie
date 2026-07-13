import 'package:fluvie_presenter/src/speaker/presentation_sync_channel.dart';

/// The conditional-import fallback: platforms without a window transport
/// have no channel, and the presenter behaves single-window.
PresentationSyncChannel? createSyncChannel() => null;
