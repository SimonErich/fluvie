part of 'source_monitor.dart';

final class _SourceMonitorState extends State<SourceMonitor> {
  int _playhead = 0;
  final FocusNode _focus = FocusNode(debugLabel: 'Source monitor');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        _length == null ||
        _length! <= 0 ||
        _entry.kind == MediaStoreKind.image) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyI) {
      _markIn();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyO) {
      _markOut();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(SourceMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.id != widget.entry.id) _playhead = 0;
    final length = _length;
    if (length != null && length > 0) _playhead = _playhead.clamp(0, length - 1);
  }

  MediaStoreEntry get _entry => widget.entry;

  /// The asset's length in frames, or null when it was never probed.
  int? get _length => _entry.durationFrames;

  NumericFormat get _format =>
      NumericFormat(unit: NumericUnit.timecode, fps: (_entry.fps ?? 30).round());

  void _seek(int frame) {
    final length = _length;
    final capped = length == null ? frame : frame.clamp(0, length - 1);
    setState(() => _playhead = capped < 0 ? 0 : capped);
  }

  /// Marks the in point here, pushing a stale out point out of the way.
  ///
  /// An in point past the out would be an inverted range, which is not a range
  /// at all; clearing the out is friendlier than refusing the mark, because the
  /// author's intent — start here — is unambiguous.
  void _markIn() {
    final out = _entry.outFrames;
    widget.onMarked(
      out != null && out <= _playhead
          ? _entry.copyWith(clearMarks: true).copyWith(inFrames: _playhead)
          : _entry.copyWith(inFrames: _playhead),
    );
  }

  /// Marks the out point here, pushing a stale in point out of the way.
  void _markOut() {
    final markIn = _entry.inFrames;
    widget.onMarked(
      markIn != null && markIn >= _playhead
          ? _entry.copyWith(clearMarks: true).copyWith(outFrames: _playhead)
          : _entry.copyWith(outFrames: _playhead),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final length = _length;
    final range = _entry.markedRange;
    final place = widget.onPlace;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Listener(
        onPointerDown: (_) => _focus.requestFocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: colors.surfaceSubtle,
                child:
                    widget.previewBuilder?.call(context, _entry, _playhead) ??
                    widget.preview ??
                    Center(child: OiLabel.small(_entry.name)),
              ),
            ),
            const SizedBox(height: 8),
            if (_entry.kind == MediaStoreKind.image)
              OiButton.primary(
                label: 'Place',
                enabled: place != null,
                onTap: place == null ? null : () => place((entry: _entry, start: 0, end: 0)),
              )
            else if (length == null || length <= 0)
              OiLabel.small(
                'This file was never probed, so it cannot be scrubbed or marked.',
                color: colors.textMuted,
              )
            else ...[
              OiSlider(
                value: _playhead.toDouble(),
                min: 0,
                max: (length - 1).toDouble(),
                label: 'Playhead',
                onChanged: (value) => _seek(value.round()),
              ),
              const SizedBox(height: 4),
              // Both rows give way rather than overflowing: a bin panel is
              // legitimately narrow, and a monitor that breaks below some width
              // would be unusable exactly where it is most needed.
              _SourceMonitorStatus(
                format: _format,
                playhead: _playhead,
                range: range,
                color: colors.textMuted,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  OiButton.secondary(label: 'Mark in', onTap: _markIn),
                  OiButton.secondary(label: 'Mark out', onTap: _markOut),
                  OiButton.ghost(
                    label: 'Clear',
                    onTap: () => widget.onMarked(_entry.copyWith(clearMarks: true)),
                  ),
                  OiButton.primary(
                    label: 'Place',
                    enabled: place != null && range != null,
                    onTap: place == null || range == null
                        ? null
                        : () => place((entry: _entry, start: range.start, end: range.end)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
