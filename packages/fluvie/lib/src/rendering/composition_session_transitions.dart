part of 'composition_session.dart';

extension _MountedTransitions on CompositionSession {
  void _validateMountedTransitions() {
    final root = mountKey.currentContext;
    if (root == null) return;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is ClipTransitionGroup) _validateClipTargets(element, widget);
      element.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
  }

  void _validateClipTargets(Element groupElement, ClipTransitionGroup group) {
    final ids = {
      for (final edge in group.transitions) ...[edge.outgoing, edge.incoming],
    };
    final targets = <String, Element>{};
    void identify(Element element) {
      final widget = element.widget;
      // Each nested group owns its own ids, even when their names are equal.
      if (widget is ClipTransitionGroup) return;
      if (widget is ElementId && ids.contains(widget.id)) {
        targets[widget.id] = element;
        return;
      }
      element.visitChildren(identify);
    }

    groupElement.visitChildren(identify);
    for (final id in ids) {
      var containsClip = false;
      final shared = <Anchor>{};
      void inspect(Element element) {
        final widget = element.widget;
        if (widget is fluvie.Clip) {
          containsClip = true;
          if (widget.shared case final anchor?) shared.add(anchor);
        }
        if (widget is SharedElement && widget.anchor != null) shared.add(widget.anchor!);
        element.visitChildren(inspect);
      }

      final target = targets[id];
      if (target != null) inspect(target);
      if (!containsClip) {
        throw FluvieTimingError(
          'ClipTransitionGroup target "$id" has no mounted Clip. '
          'Build its Clip unconditionally inside the matching ElementId and '
          'control visibility with .show(), or remove this clip transition.',
        );
      }
      if (shared.isNotEmpty) {
        throw FluvieTimingError(
          'ClipTransitionGroup target "$id" uses a shared anchor. '
          'Clip transitions need independent clip windows; remove shared from '
          'this target or use a shared-element transition between scenes.',
          anchors: shared.toList(),
        );
      }
    }
  }
}
