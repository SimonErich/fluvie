import 'package:fluvie/src/timing/timeline/resolved_timeline.dart';

/// Renders [timeline] as a fixed-width text table — the dump behind timing
/// assertions and the inspector:
///
/// ```text
/// owner | label | phase | start | end | frames
/// ------+-------+-------+-------+-----+-------
/// logo  | pop   | enter |     0 |  36 |     36
/// total: 300 frames @ 30 fps
/// ```
///
/// Column widths derive from the content (never truncating), text columns are
/// left-aligned, frame columns right-aligned, an unlabelled animation shows
/// `-`, and any warnings follow the footer as an indented block. The output
/// ends with a newline and is byte-identical for equal timelines — safe to
/// golden-test.
String debugTimeline(ResolvedTimeline timeline) {
  const headers = ['owner', 'label', 'phase', 'start', 'end', 'frames'];
  const rightAligned = [false, false, false, true, true, true];
  final rows = [
    for (final row in timeline.rows)
      [
        row.ownerId,
        row.label ?? '-',
        row.phase.name,
        '${row.startFrame}',
        '${row.endFrame}',
        '${row.durationFrames}',
      ],
  ];

  final widths = [for (final header in headers) header.length];
  for (final row in rows) {
    for (var column = 0; column < widths.length; column++) {
      if (row[column].length > widths[column]) widths[column] = row[column].length;
    }
  }
  String line(List<String> cells) => [
    for (var column = 0; column < widths.length; column++)
      rightAligned[column]
          ? cells[column].padLeft(widths[column])
          : cells[column].padRight(widths[column]),
  ].join(' | ');

  final buffer = StringBuffer()
    ..writeln(line(headers))
    ..writeln([for (final width in widths) '-' * width].join('-+-'));
  for (final row in rows) {
    buffer.writeln(line(row));
  }
  buffer.writeln('total: ${timeline.totalFrames} frames @ ${timeline.fps} fps');
  if (timeline.warnings.isNotEmpty) {
    buffer.writeln('warnings:');
    for (final warning in timeline.warnings) {
      buffer.writeln('  - $warning');
    }
  }
  return buffer.toString();
}
