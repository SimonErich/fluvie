/// @docImport 'package:fluvie_presenter/src/stepping/stop.dart';
library;

import 'package:meta/meta.dart';

/// What a [Stop] is doing at the current presentation position.
///
/// The step engine assigns one of these per `Stop` per position: hidden
/// content is genuinely absent from the tree, and revealed content runs on a
/// rebased clock so its authored entrance plays from the moment it appeared.
@immutable
sealed class StopState {
  const StopState();
}

/// The step has not been reached: the stop renders nothing.
final class HiddenStop extends StopState {
  /// Creates the hidden state.
  const HiddenStop();

  @override
  bool operator ==(Object other) => other is HiddenStop;

  @override
  int get hashCode => (HiddenStop).hashCode;
}

/// The step is active: the stop's children are mounted on a clock rebased to
/// [baseFrame].
///
/// With [skipFrames] zero the children's authored entrances play from the
/// reveal moment (a forward advance). A positive [skipFrames] starts the
/// subtree past its entrances — the settled state back navigation and jumps
/// land on — while ambient time keeps flowing.
final class RevealedStop extends StopState {
  /// Creates a revealed state rebased to [baseFrame], skipping [skipFrames].
  const RevealedStop({required this.baseFrame, this.skipFrames = 0});

  /// The slide-clock frame the subtree's frame zero maps to.
  final int baseFrame;

  /// How many subtree frames are skipped at the base — the settle offset.
  final int skipFrames;

  @override
  bool operator ==(Object other) =>
      other is RevealedStop && other.baseFrame == baseFrame && other.skipFrames == skipFrames;

  @override
  int get hashCode => Object.hash(RevealedStop, baseFrame, skipFrames);

  @override
  String toString() => 'RevealedStop(base: $baseFrame, skip: $skipFrames)';
}
