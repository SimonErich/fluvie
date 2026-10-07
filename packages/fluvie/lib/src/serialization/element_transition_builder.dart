import 'package:flutter/widgets.dart';
import 'package:fluvie/src/composition/runtime/clip_transition_audio.dart';
import 'package:fluvie/src/composition/runtime/element_transition_stack.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/audio_automation.dart';
import 'package:fluvie/src/serialization/element_builder.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/element_transition_spec.dart';
import 'package:fluvie/src/timing/placement/window_resolver.dart';
import 'package:fluvie/src/timing/time_scope_data.dart';

/// Validates that every transition names siblings in one scene/group, including
/// nested groups, before the document can be accepted by the editor or renderer.
void validateElementTransitions(
  List<ElementSpec> children,
  List<ElementTransitionSpec> transitions,
  AnchorTable anchors, {
  required int fps,
  required int durationFrames,
  List<String> path = const [],
}) {
  final found = <ElementTransitionSpec>{};
  void visit(List<ElementSpec> list, int length) {
    final ids = list.map((child) => child.id).toSet();
    final here = transitions
        .where((edge) => ids.contains(edge.outgoing) && ids.contains(edge.incoming))
        .toList();
    if (here.isNotEmpty) {
      resolveElementTransitionLayout(
        children: list,
        transitions: here,
        fps: fps,
        durationFrames: length,
        path: path,
      );
      found.addAll(here);
    }
    final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: length);
    for (final element in list.where((el) => el.type == 'Group')) {
      final window = resolveElementWindow(element.window, scope);
      visit(_groupSpecs(element, anchors), window.end - window.start);
    }
  }

  visit(children, durationFrames);
  if (found.length != transitions.length) {
    throw FluvieSpecError(
      'Transition ids must exist as siblings in the same scene or group',
      path: [...path, 'transitions'],
    );
  }
}

/// Builds a scene's children with effective overlap windows and transition
/// stacks. With no transitions it returns the original widget tree unchanged.
List<Widget> buildElementTransitions(
  List<ElementSpec> children,
  List<ElementTransitionSpec> transitions,
  AnchorTable anchors, {
  required int fps,
  required int durationFrames,
}) {
  if (transitions.isEmpty) return [for (final child in children) child.build(anchors)];
  final ids = children.map((child) => child.id).toSet();
  final here = transitions
      .where((edge) => ids.contains(edge.outgoing) && ids.contains(edge.incoming))
      .toList();
  final layout = resolveElementTransitionLayout(
    children: children,
    transitions: here,
    fps: fps,
    durationFrames: durationFrames,
  );
  final scope = TimeScopeData(fps: fps, startFrame: 0, durationFrames: durationFrames);
  final widgets = <Widget>[];
  for (final original in children) {
    var element = original;
    final window = layout.windows[element.id];
    if (window != null) {
      final raw = element.toJson();
      raw['show'] = {'from': '${window.start}f', 'to': '${window.end}f'};
      final blends = layout.blends
          .where((blend) => blend.outgoing == element.id || blend.incoming == element.id)
          .toList();
      raw['automation'] = encodeAudioAutomation(_crossfadeAutomation(element, window, blends, fps));
      element = ElementSpec.fromJson(raw, anchors);
    }
    Widget? base;
    if (element.type == 'Group') {
      final groupWindow = resolveElementWindow(element.window, scope);
      base = SizedBox.expand(
        child: Stack(
          children: buildElementTransitions(
            _groupSpecs(element, anchors),
            transitions,
            anchors,
            fps: fps,
            durationFrames: groupWindow.end - groupWindow.start,
          ),
        ),
      );
    }
    widgets.add(buildElement(element, anchors, baseOverride: base));
  }
  if (here.isEmpty) return widgets;
  return [
    ElementTransitionStack(
      ids: [for (final child in children) child.id],
      blends: layout.blends,
      children: widgets,
    ),
  ];
}

List<ElementSpec> _groupSpecs(ElementSpec group, AnchorTable anchors) => [
  for (final raw in (group.props['children']! as List).cast<Map<String, Object?>>())
    ElementSpec.fromJson(raw, anchors),
];

/// Equal-power crossfades multiply existing automation. Only frames in the
/// blend and the authored envelope points are sampled; long static clip spans
/// do not produce a per-frame allocation.
AudioAutomation _crossfadeAutomation(
  ElementSpec element,
  ({int start, int end}) window,
  List<ElementTransitionWindow> blends,
  int fps,
) => transitionAudioAutomation(
  id: element.id!,
  automation: decodeAudioAutomation(element.props['automation']),
  window: window,
  blends: blends,
  fps: fps,
);
