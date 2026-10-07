part of 'animate_section.dart';

/// The Animate panel's trigger select: the codec's keyword forms plus one
/// "when X ends / starts" pair per other element on the slide — the same
/// anchor writes a timeline link drop makes, minting the target's anchor
/// when it has none. Authored triggers the select cannot express (beat,
/// absolute times, off-slide anchors) show as a disabled `custom`.
extension _AnimateSectionTriggers on AnimateSection {
  Widget _triggerSelect(int index, Map<String, Object?> json) {
    final value = _triggerValue(json['at']);
    return OiSelect<String>(
      key: ValueKey('animate-trigger-$index'),
      value: value,
      options: [
        const OiSelectOption(value: 'auto', label: 'auto'),
        const OiSelectOption(value: 'previous', label: 'after previous'),
        const OiSelectOption(value: 'sceneStart', label: 'scene start'),
        const OiSelectOption(value: 'sceneEnd', label: 'scene end'),
        for (final target in _anchorTargets()) ...[
          OiSelectOption(value: 'whenEnds:${target.id}', label: 'when ${target.label} ends'),
          OiSelectOption(value: 'whenStarts:${target.id}', label: 'when ${target.label} starts'),
        ],
        if (value == 'custom')
          const OiSelectOption(value: 'custom', label: 'custom', enabled: false),
      ],
      onChanged: (next) => _triggerChanged(index, next),
    );
  }

  void _triggerChanged(int index, String? next) {
    if (next == null || next == 'custom') return;
    final parts = next.split(':');
    if (parts.length != 2) {
      onCommand(
        SetAnimationTriggerCommand(
          id: elementId,
          index: index,
          trigger: next == 'auto' ? null : next,
        ),
      );
      return;
    }
    final targetId = parts[1];
    final target = document.elementJson(targetId);
    if (target == null) return;
    final command = SetAnimationAnchorTriggerCommand(
      id: elementId,
      index: index,
      kind: parts[0],
      targetId: targetId,
      anchorId: target['anchor'] as String? ?? mintedAnchorId(document, targetId),
    );
    if (!resolvesAfter(document, command)) return;
    onCommand(command);
  }

  /// The select value of a raw `at`: a keyword as itself, an anchor form as
  /// `whenEnds:<targetId>` when an element on this slide declares the
  /// anchor, everything else `custom`.
  String _triggerValue(Object? at) {
    if (at == null) return 'auto';
    if (at is String) return at;
    if (at is Map<String, Object?>) {
      final kind = at['kind'];
      if (kind == 'whenEnds' || kind == 'whenStarts') {
        final target = _anchorTargets()
            .where((target) => target.anchor == at['anchor'])
            .firstOrNull;
        if (target != null) return '$kind:${target.id}';
      }
    }
    return 'custom';
  }

  /// Every other element on the slide, with its display label and declared
  /// anchor (null when it has none yet).
  List<({String id, String label, String? anchor})> _anchorTargets() {
    final targets = <({String id, String label, String? anchor})>[];
    for (final id in document.elementIdsInScene(slide)) {
      for (final candidate in [id, ...document.childIdsOfGroup(id)]) {
        if (candidate == elementId) continue;
        final json = document.elementJson(candidate) ?? const {};
        final name = document.elementMeta(candidate)['name'];
        targets.add((
          id: candidate,
          label: name is String && name.isNotEmpty ? name : (json['type'] as String? ?? candidate),
          anchor: json['anchor'] as String?,
        ));
      }
    }
    return targets;
  }
}
