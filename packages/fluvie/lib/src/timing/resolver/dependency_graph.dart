import 'dart:collection';

import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/errors/fluvie_timing_error.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';

/// The ordering pass of the two-pass trigger resolver: trigger references
/// become edges, and a topological sort yields the order in which animations
/// can be resolved to frames.
///
/// Edge rules:
///
/// * `Trigger.after` / `Trigger.whenStarts` — an edge from **every** node of
///   the referenced anchor's element (its timeline is the union of all of
///   them), so they all resolve first.
/// * `Trigger.previous` — an edge from the prior animation on the same
///   element; on a *first* animation there is no prior, which is a
///   [FluvieTimingError].
/// * `auto`, `sceneStart`, `sceneEnd`, `at`, `beat` — no edges: they depend
///   only on scopes, windows, and beat grids, never on other animations.
final class DependencyGraph {
  /// Builds the edge set for every node in [registry].
  ///
  /// Throws a [FluvieTimingError] for `Trigger.previous` on a first
  /// animation and for dangling anchor references.
  DependencyGraph.fromRegistry(AnchorRegistry registry)
    : _registry = registry,
      _edgesFrom = List.generate(registry.nodes.length, (_) => <int>[]),
      _inDegree = List.filled(registry.nodes.length, 0) {
    for (final node in registry.nodes) {
      switch (node.plan.at) {
        case AfterTrigger(:final anchor) || WhenStartsTrigger(:final anchor):
          for (final dependency in registry.nodesForAnchor(anchor)) {
            _addEdge(from: dependency.index, to: node.index);
          }
        case PreviousTrigger():
          if (node.animationIndex == 0) {
            throw firstAnimationPreviousError(node);
          }
          _addEdge(from: node.index - 1, to: node.index);
        case AutoTrigger() ||
            SceneStartTrigger() ||
            SceneEndTrigger() ||
            AbsoluteTrigger() ||
            BeatTrigger():
          break; // No dependency on another animation.
      }
    }
  }

  final AnchorRegistry _registry;
  final List<List<int>> _edgesFrom;
  final List<int> _inDegree;

  void _addEdge({required int from, required int to}) {
    _edgesFrom[from].add(to);
    _inDegree[to] += 1;
  }

  /// Every node, ordered so that each one's dependencies precede it — Kahn's
  /// algorithm, breaking ties by declaration index so the result is
  /// deterministic for a given plan.
  ///
  /// Throws a [FluvieTimingError] naming the participants of one actual
  /// cycle when the graph is not a DAG; it never hangs.
  List<AnimationNode> topologicalOrder() {
    final inDegree = List.of(_inDegree);
    final ready = SplayTreeSet<int>.of([
      for (var i = 0; i < inDegree.length; i++)
        if (inDegree[i] == 0) i,
    ]);
    final order = <AnimationNode>[];
    while (ready.isNotEmpty) {
      final index = ready.first;
      ready.remove(index);
      order.add(_registry.nodes[index]);
      for (final target in _edgesFrom[index]) {
        inDegree[target] -= 1;
        if (inDegree[target] == 0) ready.add(target);
      }
    }
    if (order.length != _registry.nodes.length) throw _cycleError(inDegree);
    return order;
  }

  /// Reconstructs one actual cycle from the nodes Kahn's algorithm could not
  /// process and names every participant.
  FluvieTimingError _cycleError(List<int> inDegree) {
    final remaining = SplayTreeSet<int>.of([
      for (var i = 0; i < inDegree.length; i++)
        if (inDegree[i] > 0) i,
    ]);
    // Each remaining node has at least one remaining predecessor (otherwise
    // its in-degree would have reached zero), so walking the smallest
    // predecessor from any start must lap a cycle. Smallest-first choices
    // keep the reported path deterministic.
    final predecessor = <int, int>{};
    for (final from in remaining) {
      for (final to in _edgesFrom[from]) {
        if (!remaining.contains(to)) continue;
        final current = predecessor[to];
        if (current == null || from < current) predecessor[to] = from;
      }
    }
    final visitedAt = <int, int>{};
    final walk = <int>[];
    var cursor = remaining.first;
    while (!visitedAt.containsKey(cursor)) {
      visitedAt[cursor] = walk.length;
      walk.add(cursor);
      cursor = predecessor[cursor]!;
    }
    // The walk follows predecessors, so the loop reversed runs along edges.
    final loop = walk.sublist(visitedAt[cursor]!).reversed.toList();
    final pivot = loop.indexOf(loop.reduce((a, b) => a < b ? a : b));
    final cycle = [...loop.sublist(pivot), ...loop.sublist(0, pivot)];
    final participants = [for (final index in cycle) _registry.nodes[index]];
    final names = [
      for (final node in participants) node.element.anchor?.debugName ?? node.element.ownerId,
    ];
    final anchors = <Anchor>[];
    for (final node in participants) {
      final anchor = node.element.anchor;
      if (anchor != null && !anchors.contains(anchor)) anchors.add(anchor);
    }
    return FluvieTimingError(
      'Trigger cycle detected: ${[...names, names.first].join(' → ')} — '
      'each waits for the next, so none can ever start. Break one of these '
      'trigger references.',
      anchors: anchors,
    );
  }
}
