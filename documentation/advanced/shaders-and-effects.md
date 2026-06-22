# Shaders and effects

Effects in Fluvie are animations. Grain, a vignette, particles, a fragment
shader: they all go in the same `.animate([...])` list as your slides and fades,
and Fluvie applies them in a fixed order. Here are two pixel effects laid over a
photo wall, in the same list as the slide that brings the tiles in:

<!-- code-excerpt "example/lib/lessons/06_collage.dart (pixel-fx)" -->
```dart
Padding(
  padding: const EdgeInsets.fromLTRB(64, 64, 64, 180),
  child:
      Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: [
          for (final photo in _photos)
            SizedBox(
              width: 280,
              height: 280,
              child: Image.asset(photo, fit: BoxFit.cover, frame: const Frame.card()),
            ),
        ],
      ).animate([
        // Transforms wrap the wall; the two pixel effects post-process
        // the result, regardless of list order.
        Animation.slideFade(stagger: const Stagger.each(Time.frames(2))),
        Animation.grain(0.18),
        Animation.vignette(0.4),
      ]),
),
```

There is no separate effects system. One list, one mechanism.

## Two classes, one order

Fluvie sorts every animation into one of two classes and always builds them the
same way:

- **Transforms** wrap the widget first: opacity, position, scale, rotation,
  blur, color. They run in list order, innermost first.
- **Pixel effects** post-process the rendered result: grain, vignette,
  scanlines, chromatic, bloom, glitch, particles, and shaders. They run last,
  in list order among themselves.

So `[slideFade, grain]` and `[grain, slideFade]` produce the same frame: the
wall slides into place, then grain lays over the result. You never order the two
classes by hand. This is the unified pipeline.

## The pixel-fx family

Each pixel effect takes its strength as a plain number and holds it across the
window:

- `Animation.grain(amount)` lays seeded monochrome speckle over the frame.
- `Animation.vignette(amount)` darkens the edges toward the center.
- `Animation.scanlines()` overlays thin dark horizontal lines for a CRT look.
- `Animation.chromatic(px)` splits the red and blue channels by a pixel offset.
- `Animation.bloom(amount)` bleeds a soft glow out of the bright areas.
- `Animation.glitchIn()` tears the frame briefly, then resolves to natural.

`amount` clamps to the range 0 to 1; `0` paints nothing. Every painter is a pure
function of the frame and its parameters, so the same input always paints the
same pixels. None of them read the backdrop or force a `saveLayer`, so they
capture cleanly off-screen.

## Particles

`Animation.particles` lays a field of particles over the element. You describe
the field with a `Particles` spec and a seed:

<!-- code-excerpt "example/lib/snippets/phase_09_snippets.dart (particles)" -->
```dart
Widget confettiCaption() =>
    const Text(
      'You did it',
      style: TextStyle(fontSize: 56, color: Color(0xFFFFFFFF)),
    ).animate([
      Animation.fadeIn(),
      Animation.particles(const Particles.confetti(seed: 'six-moments')),
    ]);
```

There are three families: `Particles.confetti`, `Particles.snow`, and
`Particles.sparkle`. Each pins its own count, palette, size range, and motion,
and you override one field at a time.

The seed is what makes the field reproducible. Each particle reads its placement
from the seeded noise source as `valueForSeed("$seed-$i")`, so a given seed lays
the field out the same way every render. That stability is what lets the frame
cache and goldens trust the output. Change the seed and you get a different but
equally stable field.

## Parallax

`Animation.parallax({depth})` drifts the element across the scene by a fraction
of its own size. It reads the scene clock, not the animation window, so the
offset is `depth` times the scene progress. Stack elements at different depths
and the small-depth layers read as far background while the large-depth ones
read as near foreground. It is a transform-class effect, so it composes with
slides and fades like any other transform.

## Seeded float

`Animation.float` bobs an element up and down forever. With no seed it is a pure
sine, the same motion it has always had. Pass a seed and the sine carries a
low-amplitude noise wobble drawn from the same seeded source as particles:

<!-- code-excerpt "example/lib/snippets/phase_09_snippets.dart (float-seed)" -->
```dart
Animation.float(amplitude: 0.04, seed: 'leaf-7');
```

The wobble is organic but reproducible, and it is sampled on a closed loop, so
it stays continuous across the cycle wrap with no jump. Two elements with
different seeds bob differently while each stays identical across runs.

## Fragment shaders (experimental)

`Animation.shader` paints a fragment shader over the element. It is the escape
hatch for effects no preset covers. Point it at a `.frag` asset registered under
`flutter: shaders:`, and Fluvie binds `resolution` and `progress` plus your
uniforms into the shader's float slots in a fixed order:

<!-- code-excerpt "example/lib/snippets/phase_09_snippets.dart (shader)" -->
```dart
Widget rippleLogo() => const ColoredBox(
  color: Color(0xFF101820),
).animate([Animation.shader('packages/fluvie/shaders/ripple.frag')]);
```

`Animation.shader` is `@experimental`: the surface may change, and a fragment
program is a GPU resource whose software-rasterizer fidelity varies by platform.
Fluvie pins its shader goldens to the Linux baseline. The bundled `ripple.frag`
ships with the package as a usable built-in and the test fixture.

Two rules keep shaders deterministic. First, the program loads once before frame
0, the same discipline media follows, so no frame ever waits on a load. A
missing or invalid asset surfaces as a `FluvieRenderException` that names the
asset. Second, every uniform is a `num` bound in iteration order, so the GLSL
contract is stable from one render to the next.

## Writing your own effect

When no preset fits, implement `AnimationEffect` for a transform or
`PixelAnimationEffect` for a pixel post-process. The marker is the only
difference: implementing `PixelAnimationEffect` opts your effect into the pixel
class, so Fluvie applies it over the transformed child:

<!-- code-excerpt "example/lib/snippets/phase_09_snippets.dart (custom-effect)" -->
```dart
Widget scanlineSweepText() => const Text(
  'Sweeping in',
  style: TextStyle(fontSize: 48, color: Color(0xFFFFFFFF)),
).animate([const Animation.custom(ScanlineSweep())]);

/// A custom pixel post-effect: implementing [PixelAnimationEffect] (not just
/// [AnimationEffect]) opts into the pixel class, so Fluvie applies it over the
/// transformed child, after every transform.
final class ScanlineSweep implements PixelAnimationEffect {
  const ScanlineSweep({this.band = 0.12});

  /// The band height, as a fraction of the child's height.
  final double band;

  @override
  Widget build(Widget child, double progress) => CustomPaint(
    foregroundPainter: _SweepPainter(progress: progress, band: band),
    child: child,
  );
}

class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress, required this.band});

  final double progress;
  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height * band;
    final top = (size.height + height) * progress - height;
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, height),
      Paint()..color = const Color(0x33FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.band != band;
}
```

Your `build` is a pure function of `progress`, the value Fluvie passes after it
applies your curve. Keep it deterministic: read the seed source for any
randomness, never `Random()` or the clock, and the frame cache and goldens stay
honest.

## Where to next

- [Timing and triggers](../guides/timing-and-triggers.md): when an effect plays
  and how `at:` chains one off another.
- [Cheatsheet](../reference/cheatsheet.md): the whole shipped surface on one
  page.
