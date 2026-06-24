import 'package:meta/meta.dart';

/// The coarse lifecycle stage of a generation job.
enum GenerationStage {
  /// The job has been accepted but has not started running yet.
  queued,

  /// The provider is actively generating the result.
  running,

  /// The result is ready and its bytes are being fetched.
  downloading,

  /// The job finished and the result is available.
  done,
}

/// A progress update emitted while a generation job runs.
@immutable
class GenerationProgress {
  /// Creates a [GenerationProgress] in [stage].
  ///
  /// [fraction] is an optional 0..1 completion estimate; [message] is an
  /// optional human-readable status line.
  const GenerationProgress({required this.stage, this.fraction, this.message});

  /// The current lifecycle stage.
  final GenerationStage stage;

  /// An optional completion estimate in the range 0..1.
  final double? fraction;

  /// An optional human-readable status message.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is GenerationProgress &&
      other.stage == stage &&
      other.fraction == fraction &&
      other.message == message;

  @override
  int get hashCode => Object.hash(stage, fraction, message);

  @override
  String toString() =>
      'GenerationProgress(stage: ${stage.name}, '
      'fraction: $fraction, message: $message)';
}
