import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The canvas tools an editor offers.
enum EditorTool {
  /// Select, move, and transform (the default; Escape always returns here).
  select,

  /// Pan the viewport by dragging.
  hand,

  /// Drop a text element and edit it inline.
  text,

  /// Draw a shape (see [ShapeVariant]).
  shape,

  /// Insert an image or video from a file.
  media,

  /// The richer insert menu (every palette element).
  element,
}

/// Which primitive the shape tool draws.
enum ShapeVariant {
  /// A stroked rectangle.
  rectangle,

  /// An ellipse (a spec circle sized by the drag).
  ellipse,

  /// A straight line.
  line,

  /// An arrow pointing where the drag ends.
  arrow,
}

/// The active tool plus its shape variant.
@immutable
final class ToolState {
  /// Creates a state for [tool] (and [shape] when it is the shape tool).
  const ToolState({required this.tool, this.shape = ShapeVariant.rectangle});

  /// The default state: the select tool.
  const ToolState.select() : this(tool: EditorTool.select);

  /// The active tool.
  final EditorTool tool;

  /// The shape the shape tool draws.
  final ShapeVariant shape;

  /// Whether this tool places elements (select and hand do not).
  bool get places => tool != EditorTool.select && tool != EditorTool.hand;

  @override
  bool operator ==(Object other) =>
      other is ToolState && other.tool == tool && other.shape == shape;

  @override
  int get hashCode => Object.hash(tool, shape);

  @override
  String toString() => 'ToolState($tool, $shape)';
}

/// The tool the canvas obeys: the toolbar, the shortcuts, and the input
/// layer all read and write this one state.
final class ToolController extends Notifier<ToolState> {
  @override
  ToolState build() => const ToolState.select();

  /// Activates [tool], keeping the current shape variant.
  void activate(EditorTool tool) => state = ToolState(tool: tool, shape: state.shape);

  /// Activates the shape tool drawing [shape].
  void pickShape(ShapeVariant shape) => state = ToolState(tool: EditorTool.shape, shape: shape);

  /// Applies a whole state (the keyboard path).
  // ignore: use_setters_to_change_properties, the command name matches activate/pickShape/reset; a setter would read as assignment.
  void apply(ToolState next) => state = next;

  /// Back to the select tool (Escape, or after a placement).
  void reset() => state = const ToolState.select();

  /// The state a bare letter shortcut activates, or null for an unbound key:
  /// V select, H hand, T text, R/O/L/A the shape variants, M media.
  static ToolState? toolForKey(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.keyV => const ToolState.select(),
    LogicalKeyboardKey.keyH => const ToolState(tool: EditorTool.hand),
    LogicalKeyboardKey.keyT => const ToolState(tool: EditorTool.text),
    LogicalKeyboardKey.keyR => const ToolState(tool: EditorTool.shape),
    LogicalKeyboardKey.keyO => const ToolState(tool: EditorTool.shape, shape: ShapeVariant.ellipse),
    LogicalKeyboardKey.keyL => const ToolState(tool: EditorTool.shape, shape: ShapeVariant.line),
    LogicalKeyboardKey.keyA => const ToolState(tool: EditorTool.shape, shape: ShapeVariant.arrow),
    LogicalKeyboardKey.keyM => const ToolState(tool: EditorTool.media),
    _ => null,
  };
}

/// The active tool for the mounted editor scope.
final toolProvider = NotifierProvider<ToolController, ToolState>(ToolController.new);
