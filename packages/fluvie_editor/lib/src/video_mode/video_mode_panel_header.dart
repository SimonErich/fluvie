part of 'video_mode_panel.dart';

/// The video panel's header: the title, the lane-edit note, the add-audio
/// picker over the media store, the transport face, and the collapse
/// toggle.
extension _VideoModePanelHeader on _VideoModePanelState {
  /// The store's audio entries — what the add-audio picker offers.
  List<MediaStoreEntry> get _audioEntries => [
    for (final entry in widget.document.mediaEntries)
      if (entry.kind == MediaStoreKind.audio) entry,
  ];

  /// Appends the picked store entry as a video-level music track.
  void _addAudio(String? id) {
    if (id == null) return;
    final entry = _audioEntries.firstWhere((entry) => entry.id == id);
    widget.onCommand(
      AddAudioTrackCommand(
        track: {'kind': 'music', 'source': Map<String, Object?>.of(entry.source)},
      ),
    );
  }

  Widget _addAudioSelect() => SizedBox(
    width: 140,
    child: OiSelect<String>(
      key: const ValueKey('video-add-audio'),
      options: [
        for (final entry in _audioEntries) OiSelectOption(value: entry.id, label: entry.name),
      ],
      placeholder: 'Add audio',
      onChanged: _addAudio,
    ),
  );

  String _readout(int frame, int totalFrames) {
    String seconds(int frames) => (frames / widget.transport.fps).toStringAsFixed(1);
    return 'f$frame · ${seconds(frame)}s / ${seconds(totalFrames)}s';
  }

  Widget _transportControls(BuildContext context, VideoLaneModel model) => ListenableBuilder(
    listenable: widget.transport,
    builder: (context, _) {
      final playing = widget.transport.isPlaying;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditorTip(
            message: playing ? 'Pause' : 'Play',
            child: OiIconButton(
              icon: playing ? OiIcons.pause : OiIcons.play,
              semanticLabel: playing ? 'Pause' : 'Play',
              size: OiButtonSize.small,
              onTap: widget.transport.toggle,
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: widget.transport.frames,
            builder: (context, frame, _) => OiLabel.small(
              _readout(frame, model.totalFrames),
              color: context.colors.textSubtle,
            ),
          ),
        ],
      );
    },
  );

  /// The razor, offered whenever the playhead sits inside a selected bar and
  /// disabled — never hidden — when it does not, so the verb stays where the
  /// hand learned to find it.
  Widget _razorButton(VideoLaneModel model) {
    final bars = _razorableBars(model);
    return EditorTip(
      message: bars.isEmpty
          ? 'Select a clip and park the playhead inside it to razor'
          : 'Razor at the playhead (B)',
      child: OiIconButton(
        icon: OiIcons.scissors,
        semanticLabel: 'Razor at playhead',
        size: OiButtonSize.small,
        onTap: bars.isEmpty ? null : () => _razor(model, bars),
      ),
    );
  }

  /// The selected bars a cut here would actually split.
  List<String> _razorableBars(VideoLaneModel model) => [
    for (final barId in ref.watch(timelineSelectionProvider).toList()..sort())
      if (videoBarRazored(
            model,
            barId,
            widget.transport.frame,
            document: widget.document,
          )?.command !=
          null)
        barId,
  ];

  /// Cuts [bars] at the playhead as one undo step, surfacing any refusal the
  /// same way a lane drag does.
  void _razor(VideoLaneModel model, List<String> bars) {
    // Every id up front: the cuts apply one after another, and minting from
    // the document each time would hand the same id to two tails.
    final ids = widget.document.nextIds(bars.length);
    final group = 'razor:${widget.transport.frame}:${bars.join(',')}';
    for (var i = 0; i < bars.length; i++) {
      _apply(
        videoBarRazored(
          model,
          bars[i],
          widget.transport.frame,
          document: widget.document,
          tailId: ids[i],
          mergeGroup: group,
        ),
      );
    }
  }

  Widget _header(BuildContext context, VideoLaneModel model) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        OiLabel.small('Video', color: context.colors.text),
        if (_note case final String note) ...[
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: OiLabel.small(
              note,
              color: context.colors.warning.base,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        EditorTip(
          message: 'Drag a transition tile onto a clip cut',
          child: OiIconButton(
            icon: OiIcons.layers,
            semanticLabel: 'Transitions',
            size: OiButtonSize.small,
            onTap: () => _refresh(() => _showTransitions = !_showTransitions),
          ),
        ),
        EditorTip(
          message: _rateStretch
              ? 'Right-edge drags change speed'
              : 'Link right-edge drags to clip speed',
          child: OiButton.ghost(
            label: _rateStretch ? 'Rate stretch: on' : 'Rate stretch',
            size: OiButtonSize.small,
            onTap: () => _refresh(() => _rateStretch = !_rateStretch),
          ),
        ),
        if (ref.watch(timelineSelectionProvider).any(model.transitionBars.containsKey))
          OiIconButton(
            icon: OiIcons.trash,
            semanticLabel: 'Remove transition',
            size: OiButtonSize.small,
            onTap: () {
              for (final id in ref.read(timelineSelectionProvider)) {
                final binding = model.transitionBars[id];
                if (binding != null) {
                  _apply(transitionRemoved(widget.document, binding));
                  break;
                }
              }
            },
          ),
        _razorButton(model),
        const SizedBox(width: 8),
        if (_audioEntries.isNotEmpty) ...[_addAudioSelect(), const SizedBox(width: 8)],
        _transportControls(context, model),
        const SizedBox(width: 8),
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
