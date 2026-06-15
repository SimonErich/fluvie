import 'package:fluvie/src/core/transition.dart';

/// One scene's transition opinions for the boundary resolver: what it wants on
/// the boundary it enters across and the boundary it exits across.
///
/// A `null` field means "no opinion" — the resolver falls through to the next
/// candidate. A non-null `Transition` (including an explicit [Transition.cut])
/// is a real value that wins where its precedence applies.
typedef SceneTransitions = ({Transition? enter, Transition? exit});

/// Resolves each scene boundary to the [Transition] that governs it, applying
/// the precedence below.
///
/// Boundary `i` sits between scene `i` (outgoing) and scene `i + 1` (incoming).
/// Per boundary the winner is:
///
/// ```text
/// scenes[i + 1].enter ?? scenes[i].exit ?? videoDefault
/// ```
///
/// — the incoming scene's `enter` beats the outgoing scene's `exit`, which
/// beats the [videoDefault]. An explicit [Transition.cut] is a real value, so
/// writing `enter: Transition.cut()` forces a hard cut over a non-cut video
/// default; `null` means "no opinion" and falls through. The result always has
/// length `scenes.length - 1` (empty for a single scene), and each entry is
/// `null` only when nothing — no scene opinion and no [videoDefault] — governs
/// that boundary, which the offset and stage math read as a cut.
List<Transition?> resolveBoundaryTransitions({
  required List<SceneTransitions> scenes,
  Transition? videoDefault,
}) => [
  for (var i = 0; i < scenes.length - 1; i++) scenes[i + 1].enter ?? scenes[i].exit ?? videoDefault,
];
