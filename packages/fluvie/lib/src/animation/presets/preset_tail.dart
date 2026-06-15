import 'package:flutter/animation.dart' show Curve;
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';

/// The common trailing parameters of every enter/exit/color preset, bundled
/// so each facade member stays a one-line delegation to its builder.
///
/// Fields mirror the `Animation` foundation constructors exactly: `duration`,
/// `ease`, and `spring` are the timing trio (`null` inherits the merged
/// `Defaults` cascade; a spring wins), and `delay`/`at`/`stagger`/
/// `repeat`/`label` are the placement tail.
typedef PresetTail = ({
  Time? duration,
  Curve? ease,
  Spring? spring,
  Time delay,
  Trigger at,
  Stagger? stagger,
  Repeat? repeat,
  String? label,
});

/// The trailing parameters of the ambient (`during`) presets.
///
/// Ambient cycle timing is pinned by each preset itself (`float`'s
/// frequency, `pulse`'s period, `spin`'s `per`), so the tail carries no
/// `duration`/`ease`/`spring`; `repeat` overrides the preset's own default
/// loop when set.
typedef AmbientTail = ({Time delay, Trigger at, Stagger? stagger, Repeat? repeat, String? label});
