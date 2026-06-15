import 'package:flutter/widgets.dart';
import 'package:fluvie/src/animation/runtime/reactive_scope.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/contracts/media_resolver.dart';

/// Wraps [child] in a [ReactiveScope] carrying the precomputed band tables for
/// [tracks], read synchronously from [resolver].
///
/// The render shell (and a live preview) calls this after the reactive
/// pre-resolve pass: the default table comes from the master source, and each
/// `Audio.track` anchor maps to its own analysed table, so a `track:`-scoped
/// reactive effect reads its track while untracked effects read the master mix.
/// A composition with no reactive tracks returns [child] unchanged — there is
/// nothing to react to, and a missing scope is the correct neutral state.
Widget reactiveScopeFor(ReactiveTracks tracks, MediaResolver resolver, Widget child) {
  final defaultSource = tracks.defaultSource;
  if (defaultSource == null) return child;
  return ReactiveScope(
    table: resolver.bandTableFor(defaultSource),
    tracks: {
      for (final entry in tracks.byAnchor.entries) entry.key: resolver.bandTableFor(entry.value),
    },
    child: child,
  );
}
