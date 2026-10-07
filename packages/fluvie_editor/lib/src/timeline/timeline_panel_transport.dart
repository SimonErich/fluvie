part of 'timeline_panel.dart';

/// The panel's header and transport face: play/pause, the frame-over-time
/// readout, the loop toggle over the ruler's range selection, and the
/// scrub — all against the one shared [SlideTransport] when the host
/// provides one (panel-local playhead state otherwise).
extension _TimelinePanelTransport on _TimelinePanelState {
  /// The playhead the ruler shows: the transport's frame, or the panel's
  /// own scrub state without a transport.
  int _playheadFrame() => widget.transport?.frame ?? _playhead;

  void _scrub(SlideTimelineModel model, double frame) {
    final next = frame.round().clamp(0, model.totalFrames);
    final transport = widget.transport;
    if (transport == null) {
      _refresh(() => _playhead = next);
    } else {
      transport.seek(next);
    }
    widget.onScrub?.call(next);
  }

  /// A ruler range selection: rounded to whole frames, retargeting an
  /// armed loop live. A selection that rounds empty changes nothing.
  void _rangeSelected(double start, double end) {
    if (start.round() == end.round()) return;
    final range = FrameRange(start.round(), end.round());
    _refresh(() => _range = range);
    final transport = widget.transport;
    if (transport != null && transport.loop != null) transport.setLoop(range);
  }

  /// Escape's clear: the selection goes and an armed loop disarms with it.
  void _rangeCleared() {
    _refresh(() => _range = null);
    widget.transport?.setLoop(null);
  }

  void _toggleLoop(SlideTransport transport) {
    if (transport.loop != null) {
      transport.setLoop(null);
    } else if (_range case final FrameRange range) {
      transport.setLoop(range);
    }
  }

  /// The exact frame over its second, over the slide's length — the
  /// readout keeps the frame first because frames are the panel's truth.
  String _readout(SlideTransport transport, int frame) {
    String seconds(int frames) => (frames / transport.fps).toStringAsFixed(1);
    return 'f$frame · ${seconds(frame)}s / ${seconds(transport.length)}s';
  }

  Widget _transportControls(BuildContext context, SlideTransport transport) => ListenableBuilder(
    listenable: transport,
    builder: (context, _) {
      final playing = transport.isPlaying;
      final looping = transport.loop != null;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditorTip(
            message: playing ? 'Pause' : 'Play',
            child: OiIconButton(
              icon: playing ? OiIcons.pause : OiIcons.play,
              semanticLabel: playing ? 'Pause' : 'Play',
              size: OiButtonSize.small,
              onTap: transport.toggle,
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: transport.frames,
            builder: (context, frame, _) => OiLabel.small(
              _readout(transport, frame),
              color: context.colors.textSubtle,
            ),
          ),
          if (_range != null || looping) ...[
            const SizedBox(width: 8),
            EditorTip(
              message: looping ? 'Stop looping' : 'Loop the selected range',
              child: OiIconButton(
                icon: OiIcons.repeat,
                semanticLabel: looping ? 'Stop looping' : 'Loop the selected range',
                size: OiButtonSize.small,
                variant: looping ? OiButtonVariant.secondary : OiButtonVariant.ghost,
                onTap: () => _toggleLoop(transport),
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _header(BuildContext context, SlideTimelineModel model) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Row(
      children: [
        OiLabel.small('Timeline', color: context.colors.text),
        if (model.validationMessage case final String message) ...[
          const SizedBox(width: 12),
          Flexible(
            child: OiLabel.small(
              message,
              color: context.colors.error.base,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const Spacer(),
        if (widget.transport case final SlideTransport transport) ...[
          _transportControls(context, transport),
          const SizedBox(width: 8),
        ],
        EditorTip(
          message: _open ? 'Collapse the timeline' : 'Show the timeline',
          child: OiIconButton(
            icon: _open ? OiIcons.panelBottomClose : OiIcons.panelBottom,
            semanticLabel: _open ? 'Collapse the timeline' : 'Show the timeline',
            size: OiButtonSize.small,
            onTap: () {
              _refresh(() => _open = !_open);
              widget.onOpenChanged?.call(_open);
            },
          ),
        ),
      ],
    ),
  );
}
