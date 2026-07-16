# Animation presets

Every preset is a static method on `Animation`. You drop it into an
`.animate([...])` list and Fluvie works out when it plays. This page lists every
preset that ships today and describes exactly what each one does on screen.

There are 31 presets in six groups, plus six low-level constructors for when no
preset fits. For how to compose and time them, see
[Animating elements](../guides/animating-elements.md).

## How to read this page

- **Phase** decides when a preset plays inside the element's window. `enter`
  plays at the start, `exit` plays at the end, and `during` plays across the
  whole window (usually on a loop). Each preset picks its own phase, so you never
  set it by hand.
- **Offsets** (the `x`/`y` a slide or drift travels) are fractions of the
  element's own size, so `1` is one element width or height. **Scale** is a
  factor where `1` is the natural size.
- **The timing tail** is shared by every preset: `duration` and `ease`, or a
  `spring` instead (the spring wins), plus `delay`, `at` (a `Trigger`),
  `stagger`, `repeat`, and `label`. Leave the timing fields unset and the
  preset inherits the `Defaults` cascade. The tables below only call out timing
  when a preset pins its own.
- **Ambient presets** (`float`, `pulse`, `drift`, `spin`, `kenBurns`, `scaleY`)
  take no `duration`/`ease`/`spring`. Their cycle timing comes from their own
  `period` or `frequency`, and their loop from `repeat`.

## Enter presets

They play at the start of the element's window.

| Preset | What it does |
| --- | --- |
| `fadeIn()` | Opacity tweens from `0` to natural. The element appears from fully transparent. |
| `slideIn({from = Edge.bottom})` | The element travels one of its own sizes from the `from` edge into place. The default rises up from below. |
| `slideFadeIn({from = Edge.bottom})` | A slide and a fade in one motion: the element moves one size from the `from` edge while its opacity tweens `0` to natural. |
| `pop({overshoot = 1.1})` | Scale springs from `0` up past the target and settles, peaking at `overshoot` (so `1.1` reaches 110% before it lands). The spring's damping is derived from `overshoot`; pass a `spring` to override it. |
| `scaleIn({from = 0.85})` | Scale springs from `from` (85% by default) to natural on `Spring.snappy`. |
| `blurIn({sigma = 12})` | A gaussian blur of `sigma` logical pixels sharpens to crisp. Blur only, so add `fadeIn()` in the same list for a blur-and-fade. |
| `maskWipeIn({shape = WipeShape.circle, origin = Alignment.center})` | A clip mask grows from `origin` and uncovers the element: hidden at the start, fully shown at the end. `circle` grows a disc until it reaches the farthest corner; `rect` grows a rectangle toward every edge; `diagonal` sweeps a top-left to bottom-right line and ignores `origin`. |

## Exit presets

They play at the end of the element's window.

| Preset | What it does |
| --- | --- |
| `fadeOut()` | Opacity tweens from natural to `0`. The element fades to transparent. |
| `slideOut({to = Edge.top})` | The element travels one of its own sizes toward the `to` edge and leaves. The default exits upward. |
| `slideFadeOut({to = Edge.top})` | The mirror of `slideFadeIn`: the element moves one size toward `to` while its opacity tweens to `0`. |
| `scaleOut({to = 0.85})` | Scale springs from natural to `to` (85% by default) on `Spring.snappy`. |
| `blurOut({sigma = 12})` | The element blurs from crisp to a gaussian blur of `sigma` logical pixels. |
| `maskWipeOut({shape = WipeShape.circle, origin = Alignment.center})` | The clip mask shrinks toward `origin` and hides the element: fully shown at the start, hidden at the end. Same three shapes as `maskWipeIn`. |

## Color and gradient

| Preset | Phase | What it does |
| --- | --- | --- |
| `color({required to})` | exit | Lerps a color toward `to` by the end of the window and publishes it through `KeyframeScope` to the element below. `Background.color` reads it and repaints the tinted fill, which is its main use; elements that do not read the scope keep their own color. |
| `gradientShift({required to})` | enter | Shifts an enclosing `Background.gradient` or `Background.radial` toward the `to` colors. The background lerps its base colors pairwise, so `to` must have the same length as the base list. Give one element a single `gradientShift` at a time. |

## Ambient motion

They play `during` the whole window. `float`, `pulse`, and `spin` loop forever
by default; `drift` and `kenBurns` run one pass. Set `repeat` to change the loop.

| Preset | What it does |
| --- | --- |
| `float({amplitude = 0.04, period = 2.5s, seed})` | Bobs up and down forever, one full cycle per `period`: it rises `amplitude` element-heights above the natural position, returns, dips the same below, and returns, on eased stops. Pass a `seed` and the bob carries a low, reproducible noise wobble, so two elements with different seeds move differently while each stays identical across renders. |
| `pulse({min = 0.97, max = 1.03, period = 1.2s})` | Breathes scale between `min` and `max` forever, one in-and-out per `period` (a yoyo loop). See the reactive form below for `pulse(on:)`. |
| `drift({to = Edge.right, distance = 0.1})` | Slides linearly from the natural position to `distance` element-sizes toward the `to` edge over the whole window. One pass, no loop. |
| `spin({period = 4s})` | Rotates one full turn (360 degrees) every `period`, linearly, forever. `repeat: Repeat.times(2)` stops after two turns. |
| `kenBurns({zoom = 1.15, pan = Edge.left})` | Slowly zooms to `zoom` while panning toward the `pan` edge, one linear pass. The pan offset is set so the zoomed element keeps covering its frame. |
| `parallax({depth = 0.2})` | Drifts the element vertically, downward for a positive `depth`, by `depth` times the scene's progress as a fraction of its own size. It reads the scene clock, not the animation window, so a small `depth` reads as a far background and a larger one as a near layer. Stack elements at different depths to build parallax. |

## Audio-reactive

They read a precomputed audio band table every frame, so they need a
`ReactiveScope` and the analysis pass before frame 0 (the render pipeline sets
this up for you). `on` picks the band (`AudioBand.bass`, `mid`, or `treble`),
`gain` scales the response, and `track` scopes it to one `Audio.track` anchor
(or the master mix when omitted).

| Preset | What it does |
| --- | --- |
| `scaleY({required on, gain = 1, track})` | Scales only the element's height by the band's energy each frame, by `1 + energy·gain`. This is the spectrum-bar look (`gain: 1.5` reaches 150% of the natural height at a band peak). |
| `pulse({required on, gain = 1, track})` | The reactive form of `pulse`. It scales the element uniformly by `1 + energy·gain` from the band, so `min`/`max`/`period` no longer apply. |

## Pixel post-effects

They post-process the already-rendered frame and always apply last, after every
transform, whatever their position in the list. None read the backdrop or force
a `saveLayer`, so they capture cleanly off-screen. The strength arguments clamp
to the range `0` to `1`, where `0` paints nothing.

| Preset | What it does |
| --- | --- |
| `grain(amount)` | Lays seeded monochrome speckle (2px blocks) over the frame. `amount` scales the speckle opacity; `progress` shimmers the field deterministically. |
| `vignette(amount)` | Darkens the corners with one radial gradient, keeping the inner ~55% bright. `amount` sets how dark the corners go. |
| `scanlines()` | Overlays 1px dark horizontal lines every 3 logical pixels for a CRT or VHS look. Takes no required argument. |
| `chromatic(px)` | Shifts the red channel `px` logical pixels one way and the blue channel `px` the other, keeps green centered, and adds the three copies back together for a lens-fringe aberration. |
| `bloom(amount)` | Adds a gaussian-blurred copy of the element over itself so its bright areas glow. `amount` sets the blur radius and the glow opacity. |
| `glitchIn({from = Edge.left})` | A brief digital tear that resolves to the clean frame: the frame is sliced into nine horizontal bands, each jittered sideways (biased toward `from`) with a chromatic split, all shrinking to zero by the end. An enter. |
| `glitchOut({to = Edge.right})` | The same seeded tear, grown from zero to full as the window ends, so the element degrades on the way out. An exit. |
| `particles(spec)` | Lays a deterministic field of particles over the element, scrolled forward by the animation's progress. `Particles.confetti` tumbles and falls, `Particles.snow` drifts down softly, and `Particles.sparkle` twinkles roughly in place. The spec's seed fixes the exact layout, so the field is identical every render. |
| `shader(asset, {uniforms})` | Paints a custom `.frag` fragment shader over the element. Fluvie binds `resolution`, then `progress`, then your `uniforms` (each a `num`) into the shader's float slots in order. Experimental. See [Shaders and effects](../advanced/shaders-and-effects.md). |

## Build your own

When no preset fits, reach for a constructor. Offsets and scale follow the same
conventions as the presets above.

| Constructor | What it does |
| --- | --- |
| `Animation.from(keyframe)` | Animates from `keyframe` to the natural state. An enter. |
| `Animation.to(keyframe)` | Animates from the natural state to `keyframe`. An exit. |
| `Animation.fromTo(a, b)` | Animates from keyframe `a` to keyframe `b`. Defaults to an enter. |
| `Animation.keyframes([...])` | Travels through a list of keyframe stops in order. `easings` shape each segment; `at` places the stops in time. |
| `Animation.along(path, {orient = true})` | Travels along a `Path` (logical pixels from the natural position). `orient` rotates the child to face the direction of travel. |
| `Animation.custom(effect)` | Wraps your own `AnimationEffect` (a transform) or `PixelAnimationEffect` (a pixel post-effect). The marker class decides which stage it runs in. |

## Where to next

- [Animating elements](../guides/animating-elements.md): how to compose, time,
  trigger, and stagger these presets.
- [Shaders and effects](../advanced/shaders-and-effects.md): the pixel-effect
  pipeline, particles, parallax, and writing your own effect.
- [Cheatsheet](cheatsheet.md): the whole public surface on one page.
