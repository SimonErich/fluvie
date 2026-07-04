// fluvie:large-file-ok: the preset static facade is one cohesive public type

import 'dart:ui' show Path;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/painting.dart' show Alignment, Color;
import 'package:fluvie/src/animation/animation_effect.dart';
import 'package:fluvie/src/animation/effects/keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/multi_keyframe_effect.dart';
import 'package:fluvie/src/animation/effects/path_effect.dart';
import 'package:fluvie/src/animation/presets/ambient_presets.dart';
import 'package:fluvie/src/animation/presets/color_presets.dart';
import 'package:fluvie/src/animation/presets/enter_exit_presets.dart';
import 'package:fluvie/src/animation/presets/gradient_presets.dart';
import 'package:fluvie/src/animation/presets/pixel_presets.dart';
import 'package:fluvie/src/animation/presets/preset_tail.dart';
import 'package:fluvie/src/animation/presets/reactive_presets.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/ease.dart';
import 'package:fluvie/src/core/edge.dart';
import 'package:fluvie/src/core/keyframe.dart';
import 'package:fluvie/src/core/particles/particles.dart';
import 'package:fluvie/src/core/repeat.dart';
import 'package:fluvie/src/core/stagger.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/timing.dart';
import 'package:fluvie/src/core/trigger.dart';
import 'package:fluvie/src/core/wipe_shape.dart';
import 'package:meta/meta.dart';

/// The one unit of motion: everything visual — transforms, opacity, color,
/// and pixel post-effects — is an [Animation] in the same `.animate([...])`
/// list.
///
/// An animation pairs *what* changes (its [effect]) with *when* it plays:
/// the [phase] within the element's window, the [timing] (tween or spring),
/// a [delay], and a [Trigger]. It deliberately shadows Flutter's `Animation`;
/// library code needing Flutter's imports it with a prefix.
///
/// ```dart
/// Text('Hi').animate([Animation.from(const Keyframe(opacity: 0, y: 0.3))]);
/// ```
@immutable
final class Animation {
  /// Animates **from** [from] to the natural state — an enter.
  Animation.from(
    Keyframe from, {
    AnimationPhase? phase,
    this.duration,
    this.ease,
    this.spring,
    this.delay = Time.zero,
    this.at = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  }) : effect = KeyframeEffect(from: from, to: Keyframe.natural),
       phase = phase ?? AnimationPhase.enter;

  /// Animates from the natural state **to** [to] — an exit.
  Animation.to(
    Keyframe to, {
    AnimationPhase? phase,
    this.duration,
    this.ease,
    this.spring,
    this.delay = Time.zero,
    this.at = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  }) : effect = KeyframeEffect(from: Keyframe.natural, to: to),
       phase = phase ?? AnimationPhase.exit;

  /// Animates from [from] to [to]; defaults to an enter unless [phase] says
  /// otherwise.
  Animation.fromTo(
    Keyframe from,
    Keyframe to, {
    AnimationPhase? phase,
    this.duration,
    this.ease,
    this.spring,
    this.delay = Time.zero,
    this.at = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  }) : effect = KeyframeEffect(from: from, to: to),
       phase = phase ?? AnimationPhase.enter;

  /// Travels through [stops] in order; defaults to an enter.
  ///
  /// [easings] shape each segment locally; [at] positions the stops in time —
  /// because `at:` names the stop positions here, the start trigger is set via
  /// [trigger] on this constructor only.
  Animation.keyframes(
    List<Keyframe> stops, {
    List<Curve>? easings,
    List<Time>? at,
    AnimationPhase? phase,
    this.duration,
    this.ease,
    this.spring,
    this.delay = Time.zero,
    Trigger trigger = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  }) : effect = MultiKeyframeEffect(stops, easings: easings, at: at),
       phase = phase ?? AnimationPhase.enter,
       at = trigger;

  /// Travels along [path] (logical px from the natural position); [orient]
  /// rotates the child to face the direction of travel. Defaults to an enter.
  Animation.along(
    Path path, {
    bool orient = true,
    AnimationPhase? phase,
    this.duration,
    this.ease,
    this.spring,
    this.delay = Time.zero,
    this.at = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  }) : effect = PathEffect(path, orient: orient),
       phase = phase ?? AnimationPhase.enter;

  /// Wraps your own [AnimationEffect]; defaults to an enter.
  const Animation.custom(
    this.effect, {
    AnimationPhase? phase,
    this.duration,
    this.ease,
    this.spring,
    this.delay = Time.zero,
    this.at = Trigger.auto,
    this.stagger,
    this.repeat,
    this.label,
  }) : phase = phase ?? AnimationPhase.enter;

  // --- Enter/exit presets — one-line delegations to builders. ---

  /// Fades in from fully transparent to the natural opacity — an enter.
  ///
  /// Expands to `Animation.from(const Keyframe(opacity: 0))`. Timing and
  /// placement come from the common tail: [duration]/[ease] or [spring]
  /// (unset inherits the `Defaults` cascade), plus [delay], [at], [stagger],
  /// [repeat], and [label].
  static Animation fadeIn({
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildFadeIn(_tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Fades out from the natural opacity to fully transparent — an exit.
  ///
  /// Expands to `Animation.to(const Keyframe(opacity: 0))`; the common tail
  /// forwards verbatim (see [fadeIn]).
  static Animation fadeOut({
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildFadeOut(_tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Slides in from one element-size off the [from] edge — an enter.
  ///
  /// Expands to `Animation.from(Keyframe(x: from.dx, y: from.dy))`: offsets
  /// are fractions of the element's own size, so the slide always starts
  /// exactly one element-width/-height away. [from] defaults to [Edge.bottom]
  /// (rises into place); the common tail forwards verbatim.
  static Animation slideIn({
    Edge from = Edge.bottom,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildSlideIn(from, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Slides out to one element-size off the [to] edge — an exit.
  ///
  /// Expands to `Animation.to(Keyframe(x: to.dx, y: to.dy))` with the same
  /// element-relative offsets as [slideIn]. [to] defaults to [Edge.top]
  /// (leaves upward); the common tail forwards verbatim.
  static Animation slideOut({
    Edge to = Edge.top,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildSlideOut(to, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Slides in from the [from] edge while fading in — an enter.
  ///
  /// Expands to `Animation.from(Keyframe(opacity: 0, x: from.dx, y:
  /// from.dy))`: one element-size of travel plus a fade in a single keyframe
  /// animation. [from] defaults to [Edge.bottom]; the common tail forwards
  /// verbatim.
  static Animation slideFadeIn({
    Edge from = Edge.bottom,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildSlideFadeIn(from, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Slides out toward the [to] edge while fading out — an exit.
  ///
  /// Expands to `Animation.to(Keyframe(opacity: 0, x: to.dx, y: to.dy))`,
  /// mirroring [slideFadeIn]. [to] defaults to [Edge.top]; the common tail
  /// forwards verbatim.
  static Animation slideFadeOut({
    Edge to = Edge.top,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildSlideFadeOut(to, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Pops in from scale `0` on a spring — an enter, springy by default.
  ///
  /// Expands to `Animation.from(const Keyframe(scale: 0), spring: …)` where
  /// the spring's damping is derived from [overshoot] via the closed form
  /// `ζ = −ln(o)/√(π² + ln²(o))`, `o = overshoot − 1`, on the default 180/1
  /// spring — so `overshoot: 1.1` peaks at exactly 110% of the natural scale.
  /// [overshoot] must lie in `(1, 2)`. An explicit [spring] replaces the
  /// derived one; the rest of the common tail forwards verbatim.
  static Animation pop({
    double overshoot = 1.1,
    Spring? spring,
    Time? duration,
    Curve? ease,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildPop(overshoot, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Scales in from [from] (a scale factor, `1` = natural size) — an enter
  /// on [Spring.snappy] by default.
  ///
  /// Expands to `Animation.from(Keyframe(scale: from), spring:
  /// Spring.snappy)`. An explicit [spring] replaces the preset spring; the
  /// rest of the common tail forwards verbatim.
  static Animation scaleIn({
    double from = 0.85,
    Spring? spring,
    Time? duration,
    Curve? ease,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildScaleIn(from, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Scales out toward [to] (a scale factor, `1` = natural size) — an exit
  /// on [Spring.snappy] by default, mirroring [scaleIn].
  ///
  /// Expands to `Animation.to(Keyframe(scale: to), spring: Spring.snappy)`.
  /// An explicit [spring] replaces the preset spring; the rest of the common
  /// tail forwards verbatim.
  static Animation scaleOut({
    double to = 0.85,
    Spring? spring,
    Time? duration,
    Curve? ease,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildScaleOut(to, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Sharpens in from a gaussian blur of [sigma] logical pixels — an enter.
  ///
  /// Expands to `Animation.from(Keyframe(blur: sigma))`. Blur-only by design:
  /// compose with [fadeIn] in the same list for blur+fade. The common tail
  /// forwards verbatim.
  static Animation blurIn({
    double sigma = 12,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildBlurIn(sigma, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Blurs out to a gaussian blur of [sigma] logical pixels — an exit.
  ///
  /// Expands to `Animation.to(Keyframe(blur: sigma))`; blur-only, mirroring
  /// [blurIn]. The common tail forwards verbatim.
  static Animation blurOut({
    double sigma = 12,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildBlurOut(sigma, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Reveals the element through a growing [shape] mask — an enter.
  ///
  /// Expands to `Animation.custom(MaskWipeEffect(shape: shape, origin:
  /// origin))`: at progress `0` the element is fully hidden, at `1` fully
  /// revealed (a circle's radius reaches the farthest corner exactly at the
  /// end). [origin] positions where the mask grows from and is ignored by
  /// [WipeShape.diagonal]. The common tail forwards verbatim.
  static Animation maskWipeIn({
    WipeShape shape = WipeShape.circle,
    Alignment origin = Alignment.center,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildMaskWipeIn(
    shape,
    origin,
    _tail(duration, ease, spring, delay, at, stagger, repeat, label),
  );

  /// Hides the element through a shrinking [shape] mask — an exit,
  /// mirroring [maskWipeIn].
  ///
  /// Expands to `Animation.custom(MaskWipeEffect(..., reverse: true))`: at
  /// progress `0` the element is fully visible, at `1` fully hidden. [origin]
  /// positions where the mask shrinks toward and is ignored by
  /// [WipeShape.diagonal]. The common tail forwards verbatim.
  static Animation maskWipeOut({
    WipeShape shape = WipeShape.circle,
    Alignment origin = Alignment.center,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildMaskWipeOut(
    shape,
    origin,
    _tail(duration, ease, spring, delay, at, stagger, repeat, label),
  );

  /// Tints toward [to] at the end of the window — color as data, an exit.
  ///
  /// Expands to `Animation.to(Keyframe(color: to))`: the lerped color travels
  /// in the per-frame composed keyframe and is consumed by color-capable
  /// elements (text, shapes, icons); the generic applier never paints it. The
  /// common tail forwards verbatim. Gradients shift via
  /// [gradientShift]; the pixel post-effects ([grain], [vignette], [scanlines],
  /// [chromatic], [bloom], [glitchIn]) post-process the rendered frame.
  static Animation color({
    required Color to,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildColor(to, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Shifts the enclosing `Background.gradient`/`radial` toward [to] — an
  /// enter, start-anchored so relative `delay`/`duration` arithmetic holds and
  /// `Trigger.whenEnds` fires when the shift completes.
  ///
  /// Expands to `Animation.custom(GradientShiftEffect(to))`: the effect
  /// publishes its shaped progress and [to] through a scope above the
  /// element, and the background lerps its base colors pairwise — [to] must
  /// be the same length as the base list. The nearest shift wins, so give an
  /// element one `gradientShift` at a time. The common tail forwards
  /// verbatim.
  static Animation gradientShift({
    required List<Color> to,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildGradientShift(to, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  // --- Pixel post-effects — post-process the rendered frame, ordered
  // outermost regardless of list position. ---

  /// Lays seeded monochrome film grain over the element — a pixel post-effect.
  ///
  /// Expands to `Animation.custom(GrainEffect(amount))`: speckle painted on top
  /// of the rendered element, every block's brightness a deterministic
  /// seeded-noise lookup. [amount] is clamped to `[0, 1]`; the common tail
  /// forwards verbatim.
  static Animation grain(
    double amount, {
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildGrain(amount, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Darkens the edges toward the center — a pixel post-effect.
  ///
  /// Expands to `Animation.custom(VignetteEffect(amount))`: one radial gradient
  /// over the element, no `saveLayer`. [amount] (clamped to `[0, 1]`) sets how
  /// dark the corners go; the common tail forwards verbatim.
  static Animation vignette(
    double amount, {
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildVignette(amount, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Overlays thin dark horizontal lines for a CRT/VHS look — a pixel
  /// post-effect taking no required parameter.
  ///
  /// Expands to `Animation.custom(ScanlinesEffect())` with the default line
  /// spacing and opacity; the common tail forwards verbatim.
  static Animation scanlines({
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildScanlines(_tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Splits the red/blue channels by [px] logical pixels for a lens-fringe
  /// aberration — a pixel post-effect.
  ///
  /// Expands to `Animation.custom(ChromaticEffect(px))`: three channel copies
  /// composited additively, capture-safe (no `BackdropFilter`). The common
  /// tail forwards verbatim.
  static Animation chromatic(
    double px, {
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildChromatic(px, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Bleeds a soft glow out of the element's bright areas — a pixel
  /// post-effect.
  ///
  /// Expands to `Animation.custom(BloomEffect(amount))`: a blurred copy
  /// (via `ImageFiltered`) added over the element, capture-safe. [amount]
  /// (clamped to `[0, 1]`) sets the glow strength; the common tail forwards
  /// verbatim.
  static Animation bloom(
    double amount, {
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildBloom(amount, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Glitches in: a brief digital tear that resolves to the natural frame — a
  /// pixel post-effect, an enter.
  ///
  /// Expands to `Animation.custom(GlitchEffect(from: from))`: seeded
  /// horizontal slice jitter plus a chromatic split, both shrinking to zero as
  /// progress reaches `1`. [from] biases the slice direction (defaults to
  /// [Edge.left]); the same seed always glitches the same way. The common tail
  /// forwards verbatim.
  static Animation glitchIn({
    Edge from = Edge.left,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildGlitchIn(from, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Glitches out: the digital tear grows until the element degrades — a
  /// pixel post-effect, an exit mirroring [glitchIn].
  ///
  /// Expands to `Animation.custom(GlitchEffect(from: to, reverse: true))`:
  /// the seeded slice jitter and chromatic split grow from zero as progress
  /// runs to `1`. [to] biases the slice direction (defaults to [Edge.right]);
  /// the same seed always tears the same way. The common tail forwards
  /// verbatim.
  static Animation glitchOut({
    Edge to = Edge.right,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildGlitchOut(to, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Lays a deterministic field of particles over the element — a pixel
  /// post-effect.
  ///
  /// Expands to `Animation.custom(ParticlesEffect(spec))`: each particle's
  /// position, rotation, size, and color are a seeded-noise lookup of its
  /// index, so the same [spec] always renders the identical field.
  /// `progress` scrolls it — confetti and snow fall, sparkle twinkles. Build
  /// the field with `Particles.confetti`/`snow`/`sparkle`; the common tail
  /// forwards verbatim.
  static Animation particles(
    Particles spec, {
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildParticles(spec, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Drifts the element by [depth] across the scene for a parallax layer — a
  /// transform-class effect.
  ///
  /// Expands to `Animation.custom(ParallaxEffect(depth: depth))`: the offset is
  /// `depth × sceneProgress` of the element's own size, read from the scene
  /// clock (not the animation window), so a small [depth] reads as a far
  /// background and a larger one as a near layer. Stack elements at different
  /// depths to compose parallax. The common tail forwards verbatim.
  static Animation parallax({
    double depth = 0.2,
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildParallax(depth, _tail(duration, ease, spring, delay, at, stagger, repeat, label));

  /// Paints a custom fragment shader over the element — an **experimental**
  /// pixel post-effect.
  ///
  /// Expands to `Animation.custom(ShaderEffect(shaderName: asset, uniforms:
  /// uniforms))`: the `.frag` at [asset] (registered under `flutter: shaders:`)
  /// is loaded once before frame 0 and painted over the rendered element. The
  /// shader's float slots are bound in a fixed order — `resolution.x`,
  /// `resolution.y`, `progress`, then each [uniforms] value (a `num`) in
  /// iteration order — so the GLSL contract is stable and deterministic.
  ///
  /// A missing or invalid asset surfaces as a `FluvieRenderException` naming the
  /// asset. Experimental: the surface may change, and software-rasterizer
  /// fidelity varies by platform (goldens are pinned to the Linux baseline). The
  /// common tail forwards verbatim.
  @experimental
  static Animation shader(
    String asset, {
    Map<String, Object> uniforms = const {},
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildShader(
    asset,
    uniforms,
    _tail(duration, ease, spring, delay, at, stagger, repeat, label),
  );

  // --- Ambient presets (continuous) — all play `during`. ---

  /// Floats gently up and down forever — a continuous ambient motion.
  ///
  /// One cycle is a vertical sine of ± [amplitude] element-heights (fractions
  /// of the element's own size), one bob per [period] (default 2.5 s). Loops
  /// forever unless [repeat] overrides.
  ///
  /// Pass a [seed] for organic variation: the pure sine then carries a
  /// low-amplitude, reproducible noise wobble drawn from the seeded noise
  /// source, so two elements with different seeds bob differently while each
  /// stays stable across runs. Sampled on a closed loop, the wobble is
  /// continuous across the cycle wrap. With no [seed] this is the unchanged
  /// pure-sine keyframe float.
  static Animation float({
    double amplitude = 0.04,
    Time period = const Time.seconds(2.5),
    String? seed,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildFloat(amplitude, period, _ambient(delay, at, stagger, repeat, label), seed: seed);

  /// Breathes scale forever — a continuous ambient pulse, in two forms.
  ///
  /// With no [on] band this is the original sine pulse: it breathes between
  /// [min] and [max] scale (relative to the natural size, `1` = unscaled), one
  /// full in-and-out cycle per [period] (default 1.2 s) — the tween runs
  /// `min → max` over half the period and the yoyo plays it back, looping
  /// yoyo-forever unless [repeat] overrides.
  ///
  /// With an [on] band this is the **reactive** pulse: it expands to
  /// `Animation.custom(ReactiveEffect(pulse, on, gain))`, scaling
  /// the element uniformly by `1 + energyAt(frame, on)·[gain]` from the
  /// precomputed band table — [min]/[max]/[period] no longer apply. [track]
  /// scopes it to one `Audio.track` anchor; `null` reads the master mix. The
  /// reactive form requires a `ReactiveScope` in capture (the precompute pass).
  static Animation pulse({
    AudioBand? on,
    double gain = 1.0,
    Anchor? track,
    double min = 0.97,
    double max = 1.03,
    Time period = const Time.seconds(1.2),
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) {
    if (on != null) {
      return buildReactivePulse(on, gain, track, _ambient(delay, at, stagger, repeat, label));
    }
    return buildPulse(min, max, period, _ambient(delay, at, stagger, repeat, label));
  }

  /// Scales the element's height by an audio band's energy forever — a
  /// spectrum-reactive `during` animation.
  ///
  /// Expands to `Animation.custom(ReactiveEffect(scaleY, on, gain))`: each frame
  /// it reads `energyAt(frame, [on])` from the precomputed band table and scales
  /// the child's Y axis by `1 + energy·[gain]` (so `gain: 1.5` reaches 150% of
  /// the natural height at a band peak). [track] scopes it to one `Audio.track`
  /// anchor; `null` reads the master mix. It requires a `ReactiveScope` in
  /// capture — the analysis runs in the precompute pass before frame 0. The
  /// ambient tail ([delay], [at], [stagger], [repeat], [label]) forwards
  /// verbatim.
  static Animation scaleY({
    required AudioBand on,
    double gain = 1.0,
    Anchor? track,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildReactiveScaleY(on, gain, track, _ambient(delay, at, stagger, repeat, label));

  /// Drifts toward the [to] edge across the whole window — a slow one-pass
  /// ambient slide.
  ///
  /// Travels linearly from the natural position to [distance] element-sizes
  /// toward [to] (default: `0.1` of the element's size to the right) over
  /// the element's window — no repeat, one pass.
  static Animation drift({
    Edge to = Edge.right,
    double distance = 0.1,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildDrift(to, distance, _ambient(delay, at, stagger, repeat, label));

  /// Spins one full turn every [period] forever — a continuous rotation.
  ///
  /// Rotation runs linearly `0 → 1` turn (360°) per cycle of [period]
  /// (default 4 s) and loops forever unless [repeat] overrides — e.g.
  /// `Repeat.times(2)` stops after two turns.
  static Animation spin({
    Time period = const Time.seconds(4),
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildSpin(period, _ambient(delay, at, stagger, repeat, label));

  /// Slowly zooms to [zoom] while panning toward the [pan] edge — the
  /// classic Ken Burns documentary move, one pass across the window.
  ///
  /// Ends at `(scale: zoom, x: −pan.dx·(zoom−1)/2, y: −pan.dy·(zoom−1)/2)`:
  /// the offset is exactly what keeps the zoomed element covering its frame
  /// while the view travels toward [pan]. Linear, no repeat.
  static Animation kenBurns({
    double zoom = 1.15,
    Edge pan = Edge.left,
    Time delay = Time.zero,
    Trigger at = Trigger.auto,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  }) => buildKenBurns(zoom, pan, _ambient(delay, at, stagger, repeat, label));

  /// Bundles the ambient preset tail for the one-line builder delegations.
  static AmbientTail _ambient(
    Time delay,
    Trigger at,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  ) => (delay: delay, at: at, stagger: stagger, repeat: repeat, label: label);

  /// Bundles the common preset tail for the one-line builder delegations.
  static PresetTail _tail(
    Time? duration,
    Curve? ease,
    Spring? spring,
    Time delay,
    Trigger at,
    Stagger? stagger,
    Repeat? repeat,
    String? label,
  ) => (
    duration: duration,
    ease: ease,
    spring: spring,
    delay: delay,
    at: at,
    stagger: stagger,
    repeat: repeat,
    label: label,
  );

  /// What this animation does to its target — built-in or custom.
  final AnimationEffect effect;

  /// When it plays within the element's window: enter, exit, or during.
  /// Inferred — `from` → enter, `to` → exit, continuous presets → during.
  final AnimationPhase phase;

  /// How long it runs; `null` inherits the merged `Defaults` duration.
  /// Ignored when [spring] is set.
  final Time? duration;

  /// The curve shaping progress; `null` inherits the merged `Defaults` ease.
  /// Ignored when [spring] is set.
  final Curve? ease;

  /// Physics-driven timing; when set it wins over [duration]/[ease] and the
  /// settle time becomes the animation's span.
  final Spring? spring;

  /// Offset applied after the trigger fires; defaults to [Time.zero].
  final Time delay;

  /// Relative to what it starts; defaults to [Trigger.auto].
  final Trigger at;

  /// Distributes start offsets across a multi-child target; `null` inherits.
  final Stagger? stagger;

  /// Loops the animation inside its span; `null` plays a single pass.
  final Repeat? repeat;

  /// Names this animation so others can chain off it; diagnostics only.
  final String? label;

  /// The anatomy view of the three timing fields: [spring] wins; an explicit
  /// [duration] makes a [Tween] (with [ease] or `Ease.smooth`); all-unset is
  /// `null`, deferring to the inherited `Defaults`.
  Timing? get timing {
    final explicitSpring = spring;
    if (explicitSpring != null) return explicitSpring;
    final explicitDuration = duration;
    if (explicitDuration == null) return null;
    return Tween(explicitDuration, ease: ease ?? Ease.smooth);
  }

  @override
  String toString() =>
      'Animation(${phase.name}, effect: $effect, timing: $timing, '
      'delay: $delay, at: $at${label == null ? '' : ", label: '$label'"})';
}
