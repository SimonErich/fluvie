part of 'command_scope.dart';

/// Everything a registry command reads to decide whether it applies and to
/// act: the document, the slide on stage, the selection, and the callbacks
/// back into the surface that built the scope.
///
/// A scope is a cheap snapshot — the canvas builds one per dispatch, the
/// slide strip one per tile. Callbacks a surface cannot serve default to
/// inert no-ops, so a minimal scope stays honest about what it can do.
final class CommandScope {
  /// Snapshots the editing surface over [document] with [slide] on stage.
  CommandScope({
    required this.document,
    required this.slide,
    required this.dispatch,
    this.selection = const {},
    this.enteredGroup,
    this.clipboard,
    this.frameOrigin = Offset.zero,
    Size? frameSize,
    this.select = _ignoreIds,
    this.exitGroup = _noop,
    this.showSlide = _ignoreSlide,
    this.editMaster = _ignoreMaster,
    this.rectOf = _noRect,
    this.canUndo = false,
    this.canRedo = false,
    this.undo = _noop,
    this.redo = _noop,
    this.playhead = 0,
    this.timelineSelection = const {},
    this.activeLane,
    this.markIn,
    this.markOut,
    this.seek,
    this.setMarks,
    this.snapEnabled = true,
    this.toggleSnap,
  }) : frameSize = frameSize ?? _canvasSizeOf(document);

  /// The deck being edited.
  final EditorDocument document;

  /// The slide the commands act on.
  final int slide;

  /// The selected element ids.
  final Set<String> selection;

  /// The entered group scoping edits, or null at the top level.
  final String? enteredGroup;

  /// The clipboard, or null on a surface without one (the slide strip).
  final EditorClipboard? clipboard;

  /// Sends a document command into the owner's history.
  final void Function(EditorCommand command) dispatch;

  /// Replaces the selection.
  final void Function(Set<String> ids) select;

  /// Leaves the entered group.
  final VoidCallback exitGroup;

  /// Puts a slide on stage.
  final void Function(int slide) showSlide;

  /// Opens a master in master-edit mode (surfaces without one stay inert).
  final void Function(String name) editMaster;

  /// The resolved layout rect of an element in canvas pixels, or null while
  /// its size is unknown (or on a surface without geometry).
  final Rect? Function(String id) rectOf;

  /// Whether the host's history holds an undo step (false on a surface
  /// without a history — the Undo command then reads as disabled).
  final bool canUndo;

  /// Whether the host's history holds a redo step.
  final bool canRedo;

  /// Undoes one history step (inert on a surface without a history).
  final VoidCallback undo;

  /// Redoes one history step (inert on a surface without a history).
  final VoidCallback redo;

  /// The composition frame the playhead is parked on.
  ///
  /// Zero on a surface with no transport, which is why every command that
  /// needs one asks whether it is *inside* something rather than trusting it:
  /// frame zero is a real position, not a null.
  final int playhead;

  /// The timeline bars selected, by their bar id.
  ///
  /// Separate from [selection] because they are different things. Selecting a
  /// bar selects a span of time on a lane; selecting an element selects a
  /// thing on the canvas. A razor acts on the first and an align acts on the
  /// second, and conflating them would make each apply where it cannot.
  final Set<String> timelineSelection;

  /// The lane new material lands on, or null where the surface has no lanes.
  final String? activeLane;

  /// The in point marked on the timeline, in composition frames, or null.
  final int? markIn;

  /// The out point marked on the timeline, or null.
  final int? markOut;

  /// Moves the playhead, or null on a surface with no transport.
  ///
  /// Nullable rather than an inert no-op, unlike the older callbacks: the
  /// timeline commands need to *know* whether a transport exists so they can
  /// read as disabled, and a no-op is indistinguishable from a working seek
  /// that happened to land where it already was.
  final void Function(int frame)? seek;

  /// Replaces the in and out marks, or null on a surface with no transport.
  final void Function({int? markIn, int? markOut})? setMarks;

  /// Whether timeline/canvas gestures currently snap.
  final bool snapEnabled;

  /// Toggles the shared snapping preference, null on non-editing surfaces.
  final VoidCallback? toggleSnap;

  /// Whether this surface has a transport at all.
  bool get canSeek => seek != null;

  /// Marks the in point at [frame], pushing a stale out point out of the way.
  ///
  /// An in at or past the out is an inverted span, which is not a span; the
  /// author's intent is unambiguous, so the stale mark gives way rather than
  /// the new one being refused.
  void setMarkIn(int frame) {
    final out = markOut;
    setMarks?.call(markIn: frame, markOut: out != null && out <= frame ? null : out);
  }

  /// Marks the out point at [frame], pushing a stale in point out of the way.
  void setMarkOut(int frame) {
    final start = markIn;
    setMarks?.call(markIn: start != null && start >= frame ? null : start, markOut: frame);
  }

  /// Drops both marks.
  void clearMarks() => setMarks?.call();

  /// The marked span, or null when it is not a span.
  ///
  /// An out at or before the in is not a range, and neither is half a mark, so
  /// a command that needs a span gets null rather than a guess.
  ({int start, int end})? get markedSpan {
    final start = markIn;
    final end = markOut;
    if (start == null || end == null || end <= start) return null;
    return (start: start, end: end);
  }

  /// Where the editing frame sits on the canvas (zero at the top level).
  final Offset frameOrigin;

  /// The pixel space the current scope's placements resolve against: the
  /// slide, or the entered group's box.
  final Size frameSize;

  /// The slide's pixel size.
  Size get canvasSize => _canvasSizeOf(document);

  /// The ids the current scope edits: the slide's top level, or the entered
  /// group's children.
  List<String> get scopeIds {
    final entered = enteredGroup;
    return entered == null ? document.elementIdsInScene(slide) : document.childIdsOfGroup(entered);
  }

  /// The selection in document z-order (sets carry no order).
  List<String> get orderedSelection => [
    for (final id in scopeIds)
      if (selection.contains(id)) id,
  ];

  /// The selected master-slot fills, in slot order. Fills stay off the
  /// z-order surfaces ([scopeIds] — their z is the master's slot order), so
  /// the commands that honestly apply to them read this separately.
  List<String> get selectedFills => [
    for (final id in document.fillIdsInScene(slide))
      if (selection.contains(id)) id,
  ];

  /// Whether [id] is locked through its editor metadata.
  bool isLocked(String id) => document.elementMeta(id)['locked'] == true;

  /// Whether [id] is hidden through the spec's `visible` flag.
  bool isHidden(String id) => document.elementJson(id)?['visible'] == false;
}
