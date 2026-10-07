import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';

part 'master_edit_readback.dart';

/// Master-edit mode's document lens: a synthetic single-scene [view] whose
/// scene IS the master definition, and the [translate] step that maps every
/// command the editing surfaces dispatch against the view back onto the
/// real document's `masters` block as one [SetMasterCommand].
///
/// The view mints transient ids that never persist: chrome children read
/// `m-<index>`, placeholders `s-<index>` (rendered as labeled outline
/// groups). Translation applies the command to the view, reads the edited
/// scene back into master JSON — stripping every identity key at any depth
/// — and refuses (returns null) anything that would remove or bury a
/// placeholder, throws, or changes nothing.
final class MasterEditSession {
  /// Opens the master [name] of [document] for editing. Throws an
  /// [ArgumentError] for a name the document does not define.
  MasterEditSession(EditorDocument document, this.name)
    : _master = document.masterJson(name) ?? _unknown(name),
      _documentJson = document.toJson() {
    _placeholders = <int, Map<String, Object?>>{};
    final children = _master['children'];
    if (children is List) {
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        if (child is Map<String, Object?> && child['type'] == 'Placeholder') {
          _placeholders[i] = child;
        }
      }
    }
    view = EditorDocument.fromJson(_viewJson());
  }

  /// The master being edited.
  final String name;

  final Map<String, Object?> _master;
  final Map<String, Object?> _documentJson;
  late final Map<int, Map<String, Object?>> _placeholders;

  /// The synthetic single-scene document the canvas and inspector edit.
  late final EditorDocument view;

  /// The default box a transformless placeholder shows in the view.
  static const Map<String, Object?> defaultSlotTransform = {
    'x': 0.5,
    'y': 0.5,
    'w': 0.6,
    'h': 0.25,
  };

  /// Maps [command] — dispatched against [view] — onto the real document:
  /// the command applies to the view, the edited scene reads back into
  /// master JSON, and the result arrives as a [SetMasterCommand] (carrying
  /// the command's merge key, so streams keep coalescing). Null when the
  /// command does not apply, changes nothing of the master, or would
  /// remove or bury a placeholder.
  EditorCommand? translate(EditorCommand command) {
    final EditorDocument next;
    try {
      next = command.apply(view);
    } on Object {
      return null;
    }
    final master = _readBack(next.sceneJson(0));
    if (master == null || _deepEquals(master, _master)) return null;
    return SetMasterCommand(name: name, master: master, mergeGroup: command.mergeKey);
  }

  Map<String, Object?> _viewJson() => {
    'fluvieSpec': 1,
    'size': _documentJson['size'],
    'fps': _documentJson['fps'],
    if (_documentJson['motionDefaults'] != null) 'motionDefaults': _documentJson['motionDefaults'],
    if (_documentJson['theme'] != null) 'theme': _documentJson['theme'],
    'scenes': [
      {
        'duration': '5s',
        'layout': 'canvas',
        if (_master['background'] != null) 'background': _master['background'],
        'children': [
          for (final (index, child) in _masterChildren().indexed)
            if (_placeholders.containsKey(index))
              _placeholderElement(index, _placeholders[index]!)
            else
              {...child, 'id': 'm-$index'},
        ],
      },
    ],
  };

  List<Map<String, Object?>> _masterChildren() {
    final children = _master['children'];
    if (children is! List) return const [];
    return children.whereType<Map<String, Object?>>().toList();
  }

  /// A placeholder's face in the view: a labeled outline group, selectable
  /// and movable as one unit (E15's group rule), never deletable.
  Map<String, Object?> _placeholderElement(int index, Map<String, Object?> placeholder) => {
    'type': 'Group',
    'id': 's-$index',
    'transform': placeholder['transform'] ?? defaultSlotTransform,
    'children': [
      {
        'type': 'Box',
        'id': 's-$index-box',
        'decoration': {
          'color': '#14FFFFFF',
          'cornerRadius': 8,
          'border': {'color': '#806C5CE7', 'width': 2},
        },
        'transform': {'x': 0.5, 'y': 0.5, 'w': 1.0, 'h': 1.0},
      },
      {
        'type': 'Text',
        'id': 's-$index-label',
        'text': placeholder['slot'],
        'style': {'color': '#B3FFFFFF', 'fontSize': 24},
        'transform': {'x': 0.5, 'y': 0.5},
      },
    ],
  };

  static Never _unknown(String name) =>
      throw ArgumentError.value(name, 'name', 'No master with this name');
}
