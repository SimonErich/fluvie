import 'package:fluvie/src/timing/plan/composition_plan.dart';
import 'package:fluvie/src/timing/plan/element_plan.dart';
import 'package:fluvie/src/timing/resolver/anchor_registry.dart';
import 'package:fluvie/src/timing/resolver/composition_resolver.dart';
import 'package:fluvie/src/timing/resolver/trigger_resolver.dart';

/// What [resolvePlan] hands back to a test: the spans keyed by node index,
/// plus the live pipeline pieces for direct assertions (anchor timelines,
/// registry lookups, element windows).
typedef ResolvedPlan = ({
  Map<int, ResolvedSpan> spans,
  AnchorRegistry registry,
  TriggerResolver resolver,
  Map<ElementPlan, ResolvedSpan> windows,
});

/// Thin adapter over `resolveCompositionDetailed` — the *single* resolution
/// code path since Epic 3.4 — exposing the white-box pieces the Epic 3.3
/// resolver tests assert against.
ResolvedPlan resolvePlan(CompositionPlan plan) {
  final detailed = resolveCompositionDetailed(plan);
  return (
    spans: detailed.spans,
    registry: detailed.registry,
    resolver: detailed.resolver,
    windows: detailed.windows,
  );
}
