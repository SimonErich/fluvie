import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/placement.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/background_spec.dart';
import 'package:fluvie/src/serialization/codecs/placement_codec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';

part 'master_child_specs.dart';
part 'master_spec_parser.dart';

/// A reusable slide layout the document's scenes adopt by name: an optional
/// [background], fixed chrome children, and named [PlaceholderSpec] slots a
/// scene fills through its `fills` map (see `SceneSpec.master`).
///
/// A master is applied at build time by [resolveSceneMaster] — no copies —
/// so editing a master's definition changes every adopting scene on the next
/// build. Master children carry no `id`, `anchor`, or `shared`: they are
/// chrome instantiated per adopting scene, not per-scene editable elements
/// (identity belongs to the scene's own fills and children).
final class MasterSpec {
  /// Creates a master from its parts; absent parts are empty.
  MasterSpec({this.background, this.layout = SceneLayout.stack, this.children = const []});

  /// Reads a master from [json], resolving any animation anchors inside its
  /// fixed children through [anchors].
  ///
  /// Throws a [FluvieSpecError] (located under [path]) for a malformed child,
  /// an identity key (`id`/`anchor`/`shared`) at any depth of a fixed child,
  /// a placeholder without an identifier `slot`, or a duplicate slot.
  factory MasterSpec.fromJson(
    Map<String, Object?> json,
    AnchorTable anchors, {
    List<String> path = const [],
  }) => _parseMaster(json, anchors, path);

  /// The keys a master object reads; the single source of truth for the
  /// master's unknown-property check, in step with [MasterSpec.fromJson].
  static const Set<String> knownKeys = {'background', 'layout', 'children'};

  /// The backdrop every adopting scene inherits unless it declares its own.
  final BackgroundSpec? background;

  /// The authoring intent for the master's own editing canvas; the adopting
  /// scene keeps its own `layout` (rendering reads neither).
  final SceneLayout layout;

  /// The ordered children: fixed chrome ([MasterElementSpec]) and named
  /// slots ([PlaceholderSpec]), layered in this order under every adopting
  /// scene's own children.
  final List<MasterChildSpec> children;

  /// The slot names this master offers.
  Set<String> get slots => {
    for (final child in children)
      if (child is PlaceholderSpec) child.slot,
  };

  /// The JSON form: only the declared parts, canonically encoded.
  Map<String, Object?> toJson() => {
    if (background != null) 'background': background!.toJson(),
    if (layout != SceneLayout.stack) 'layout': layout.name,
    if (children.isNotEmpty) 'children': [for (final child in children) child.toJson()],
  };

  /// Applies this master to [scene]: the master background unless the scene
  /// declares its own, then the master children (each placeholder replaced
  /// by its fill, unfilled slots skipped), then the scene's own children on
  /// top. Throws a [FluvieSpecError] (located under [path]) for a fill
  /// naming a slot this master does not define.
  SceneSpec apply(SceneSpec scene, {List<String> path = const []}) {
    for (final slot in scene.fills.keys) {
      if (slots.contains(slot)) continue;
      throw FluvieSpecError(
        'Unknown slot "$slot"; the master defines ${_names(slots)}',
        path: [...path, 'fills', slot],
      );
    }
    return SceneSpec(
      duration: scene.duration,
      background: scene.background ?? background,
      layout: scene.layout,
      audio: scene.audio,
      children: [
        for (final child in children)
          ...switch (child) {
            MasterElementSpec(:final element) => [element],
            final PlaceholderSpec placeholder => switch (scene.fills[placeholder.slot]) {
              null => const <ElementSpec>[],
              final fill => [_filled(fill, placeholder)],
            },
          },
        ...scene.children,
      ],
      enter: scene.enter,
      exit: scene.exit,
      motionDefaults: scene.motionDefaults,
      steps: scene.steps,
      notes: scene.notes,
      transitions: scene.transitions,
    );
  }
}

/// Resolves [scene] against the document's [masters]: a scene without a
/// master passes through untouched (the same instance); an adopting scene
/// returns its fully freeform form with the master applied (see
/// [MasterSpec.apply]). Throws a [FluvieSpecError] (located under [path])
/// for an unknown master name, an unknown fill slot, or fills without a
/// master. `VideoSpec.build`, the presenter, and the editor all resolve
/// through this one function, so masters apply identically everywhere.
SceneSpec resolveSceneMaster(
  SceneSpec scene,
  Map<String, MasterSpec> masters, {
  List<String> path = const [],
}) {
  final name = scene.master;
  if (name == null) {
    if (scene.fills.isEmpty) return scene;
    throw FluvieSpecError('"fills" need a "master" to fill', path: [...path, 'fills']);
  }
  final master = masters[name];
  if (master == null) {
    throw FluvieSpecError(
      'Unknown master "$name"; the document defines ${_names(masters.keys)}',
      path: [...path, 'master'],
    );
  }
  return master.apply(scene, path: path);
}

ElementSpec _filled(ElementSpec fill, PlaceholderSpec placeholder) => ElementSpec(
  type: fill.type,
  props: _mergedProps(fill.props, placeholder.style),
  id: fill.id,
  placement: fill.placement ?? placeholder.placement,
  anchor: fill.anchor,
  shared: fill.shared,
  visible: fill.visible,
  animate: fill.animate,
);

/// [style] merged under the fill's own `style` per field (the fill wins). A
/// non-map fill style passes through untouched for its codec to report.
Map<String, Object?> _mergedProps(Map<String, Object?> props, Map<String, Object?>? style) {
  if (style == null) return props;
  final own = props['style'];
  if (own != null && own is! Map<String, Object?>) return props;
  return {
    ...props,
    'style': {...style, ...?(own as Map<String, Object?>?)},
  };
}

String _names(Iterable<String> names) {
  if (names.isEmpty) return 'no names';
  final sorted = names.toList()..sort();
  return sorted.map((name) => '"$name"').join(', ');
}
