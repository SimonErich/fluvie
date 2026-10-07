part of 'source_monitor.dart';

/// Lets each complete status label use the monitor's available width.
///
/// The labels share a run only when they fit together. A range can wrap within
/// its own run instead of inheriting half the space left by the timecode.
final class _SourceMonitorStatus extends StatelessWidget {
  const _SourceMonitorStatus({
    required this.format,
    required this.playhead,
    required this.range,
    required this.color,
  });

  final NumericFormat format;
  final int playhead;
  final ({int start, int end})? range;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final marked = range;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 4,
      runSpacing: 4,
      children: [
        OiLabel.small(format.format(playhead.toDouble()), color: color),
        OiLabel.small(
          marked == null
              ? 'no range'
              : '${format.format(marked.start.toDouble())} '
                    '- ${format.format(marked.end.toDouble())}',
          color: color,
        ),
      ],
    );
  }
}
