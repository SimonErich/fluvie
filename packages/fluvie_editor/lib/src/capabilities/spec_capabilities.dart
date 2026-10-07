import 'package:fluvie/fluvie.dart' show knownElementTypes;

/// What the spec can express — the gate between the insert palette and the
/// document, so the editor never offers an element it cannot save.
///
/// The insertable set IS fluvie's `knownElementTypes`: the palette is a
/// subset of the serializable world by construction, and it grows the moment
/// a codec lands.
final class SpecCapabilities {
  /// Creates the registry.
  const SpecCapabilities();

  /// Every element type the palette may offer.
  Set<String> get insertableTypes => knownElementTypes;

  /// Whether an element of [type] can be inserted (and therefore saved).
  bool supports(String type) => knownElementTypes.contains(type);

  /// The minimal valid element JSON an insert starts from. Content elements
  /// carry a centered `transform` so the gizmo can grab them immediately;
  /// annotations carry pixel geometry the shape tool overwrites as it drags.
  ///
  /// Throws an [ArgumentError] for a type the spec cannot express.
  Map<String, Object?> defaultElementJson(String type) => switch (type) {
    'Text' || 'SplitText' => {
      'type': type,
      if (type == 'SplitText') 'by': 'word',
      'text': 'Text',
      'style': {'color': '#F9FAFB', 'fontSize': 48},
      'transform': {'x': 0.5, 'y': 0.5},
    },
    'Box' => {
      'type': 'Box',
      'color': '#6C5CE7',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.25, 'h': 0.25},
    },
    'Image' => {
      'type': 'Image',
      'source': {'kind': 'asset', 'value': ''},
      'fit': 'cover',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.3, 'h': 0.3},
    },
    'Counter' => {
      'type': 'Counter',
      'to': 100,
      'reveal': '1s',
      'transform': {'x': 0.5, 'y': 0.5},
    },
    'Clip' => {
      'type': 'Clip',
      'source': {'kind': 'asset', 'value': ''},
      'fit': 'cover',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.4},
    },
    'Shape' => {
      'type': 'Shape',
      'kind': 'rect',
      'rect': {'x': 810, 'y': 440, 'w': 300, 'h': 200},
    },
    'Arrow' => {
      'type': 'Arrow',
      'from': {'x': 760, 'y': 640},
      'to': {'x': 1160, 'y': 440},
    },
    'Connector' => {
      'type': 'Connector',
      'from': {'x': 760, 'y': 440},
      'to': {'x': 1160, 'y': 640},
      'elbow': true,
    },
    'Typewriter' => {
      'type': 'Typewriter',
      'text': 'Typed out',
      'caret': true,
      'transform': {'x': 0.5, 'y': 0.5},
    },
    'Markdown' => {
      'type': 'Markdown',
      'source': '# Heading\n\n- first\n- second',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.5},
    },
    'Terminal' => {
      'type': 'Terminal',
      'lines': [
        {'cmd': 'echo hello'},
        {'out': 'hello'},
      ],
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.4},
    },
    'Code' => {
      'type': 'Code',
      'source': 'void main() {}',
      'language': 'dart',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.4},
    },
    'Chart' => {
      'type': 'Chart',
      'variant': 'bar',
      'data': {'A': 3, 'B': 5, 'C': 2},
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    },
    'Mermaid' => {
      'type': 'Mermaid',
      'source': 'graph TD; A-->B;',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    },
    'WebView' => {
      'type': 'WebView',
      'uri': 'https://example.com',
      'viewport': {'width': 1280, 'height': 800},
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    },
    'Html' => {
      'type': 'Html',
      'source': '<h1>Hello</h1>',
      'viewport': {'width': 1280, 'height': 800},
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    },
    'Bars' => {
      'type': 'Bars',
      'transform': {'x': 0.5, 'y': 0.85, 'w': 0.8, 'h': 0.2},
    },
    'LowerThird' => {
      'type': 'LowerThird',
      'name': 'Name',
      'title': 'Title',
    },
    'TitleCard' => {
      'type': 'TitleCard',
      'title': 'Title',
      'subtitle': 'Subtitle',
    },
    'Snapshot' => {
      'type': 'Snapshot',
      'child': {'type': 'Text', 'text': 'Snapshot'},
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    },
    'DeviceFrame' => {
      'type': 'DeviceFrame',
      'variant': 'browser',
      'child': {'type': 'Text', 'text': 'Framed'},
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.6},
    },
    'Callout' => {
      'type': 'Callout',
      'label': 'Look here',
      'target': {'x': 960, 'y': 540},
      'child': {'type': 'Box', 'color': '#00000000'},
    },
    'Spotlight' => {
      'type': 'Spotlight',
      'region': {'x': 760, 'y': 440, 'w': 400, 'h': 200},
      'child': {'type': 'Box', 'color': '#00000000'},
    },
    // A fresh group starts empty; grouping a selection (epic 5.3) moves
    // existing elements into `children`.
    'Group' => {
      'type': 'Group',
      'children': <Object?>[],
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    },
    _ => throw ArgumentError.value(type, 'type', 'The spec cannot express this element'),
  };
}
