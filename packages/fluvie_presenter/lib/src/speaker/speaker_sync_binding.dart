import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/controller/presentation_controller.dart';
import 'package:fluvie_presenter/src/speaker/presentation_sync_channel.dart';
import 'package:fluvie_presenter/src/speaker/sync_message.dart';

/// Keeps this window's presentation position in lockstep with the other
/// window over the sync channel.
///
/// The primary end (the presenting window) applies incoming navigation
/// requests through its controller — so forward moves keep their forward
/// semantics, entrances and all — and broadcasts every position change. The
/// speaker end follows position updates instantly and never broadcasts;
/// its own inputs travel as navigation requests instead.
///
/// With no channel on this platform the binding is a transparent
/// passthrough of [child].
final class SpeakerSyncBinding extends ConsumerStatefulWidget {
  /// Binds [child]'s presentation scope to the channel.
  const SpeakerSyncBinding({required this.child, this.isPrimary = true, super.key});

  /// Whether this is the presenting window (applies navigation requests and
  /// broadcasts positions) or the speaker window (follows).
  final bool isPrimary;

  /// The subtree presenting from the bound scope.
  final Widget child;

  @override
  ConsumerState<SpeakerSyncBinding> createState() => _SpeakerSyncBindingState();
}

final class _SpeakerSyncBindingState extends ConsumerState<SpeakerSyncBinding> {
  StreamSubscription<SyncMessage>? _subscription;
  bool _applyingRemote = false;

  @override
  void initState() {
    super.initState();
    final channel = ref.read(presentationSyncChannelProvider);
    if (channel == null) return;
    _subscription = channel.messages.listen(_onMessage);
    if (widget.isPrimary) {
      ref.listenManual(presentationControllerProvider, (previous, next) {
        if (_applyingRemote) return;
        if (previous?.position == next.position) return;
        channel.send(PositionUpdate(next.position));
      });
      // Late-joining speaker windows ask where the deck stands by sending a
      // position of their own; simplest bootstrap: announce ours once.
      channel.send(PositionUpdate(ref.read(presentationControllerProvider).position));
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _onMessage(SyncMessage message) {
    final controller = ref.read(presentationControllerProvider.notifier);
    _applyingRemote = true;
    try {
      switch (message) {
        case PositionUpdate(:final position):
          if (ref.read(presentationControllerProvider).position != position) {
            controller.jumpToStep(position.slide, position.step);
          }
        case NavigationRequest(:final action, :final target):
          if (!widget.isPrimary) return;
          _applyingRemote = false; // The resulting move must broadcast.
          switch (action) {
            case NavigationAction.next:
              controller.next();
            case NavigationAction.back:
              controller.back();
            case NavigationAction.jump:
              controller.jumpToStep(target!.slide, target.step);
          }
      }
    } finally {
      _applyingRemote = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
