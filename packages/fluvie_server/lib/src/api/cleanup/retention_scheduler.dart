import 'dart:async';

import 'package:fluvie_server/src/api/cleanup/retention_service.dart';

/// Runs a [RetentionService] sweep on a fixed interval.
///
/// [start] is a no-op when the interval is zero (the deployment relies on the
/// `/maintenance/cleanup` endpoint instead). [onSweep] receives each report,
/// for logging.
final class RetentionScheduler {
  /// Creates a scheduler for [service] firing every [interval].
  RetentionScheduler(this.service, {required this.interval, this.onSweep});

  /// The retention service to run.
  final RetentionService service;

  /// How often to sweep; [Duration.zero] disables the timer.
  final Duration interval;

  /// Called with each sweep's report (for logging), if set.
  final void Function(RetentionReport report)? onSweep;

  Timer? _timer;

  /// Starts the periodic timer (no-op when [interval] is zero or already running).
  void start() {
    if (interval <= Duration.zero || _timer != null) return;
    _timer = Timer.periodic(interval, (_) async {
      final report = await service.sweep();
      onSweep?.call(report);
    });
  }

  /// Stops the timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
