# Colour

Open the **Colour** workspace and select a clip or an element. Colour effects
use the same effect stack in the preview, saved document, generated Dart and
export. The original media stays untouched.

## Start with a Look

Choose **Social pop**, **Clear speaker**, **Studio clean** or **Warm cinema**.
Set **Look intensity** first; 0.6 gives a useful starting point. Applying a Look
replaces the selected elements' colour treatment in one undo step, preserving
other effects. The applied intensity remains editable on the grade or LUT.

**Copy grade** copies only grade, curves and LUT effects using the effects
clipboard format. **Paste grade** replaces the colour treatment of every
selected element. **Paste to lane** applies it to clips on the selected element's
declared lane. Clipboard payloads travel between documents and app windows.

## Correct colour

**Add correction** supplies exposure, contrast, saturation, temperature and tint.
White balance applies first, then exposure, contrast and saturation. The wheel
adjusts temperature and tint together; both also have keyboard-editable numeric
fields. A wheel drag commits once on release. Intensity mixes the resulting
colour matrix with the identity matrix; zero is an exact no-op.

Every numeric field accepts arithmetic and has a diamond to turn it into a
keyframed value. Effect rows in the timeline expose its stops. Keyframed white
balance values are edited through their numeric/timeline controls rather than
the two-channel wheel.

## Shape a curve

**Add curves** opens master, red, green and blue channels. Select a channel and a
point, drag it on the graph, or edit **Input** and **Output** numerically. **Add
point** divides the widest interval without changing the curve's sampled value;
**Remove point** keeps at least two points. **Reset curve** restores the diagonal.
The graph and renderer share the monotone cubic evaluator, with no overshoot
between monotone points. Every point stays inside the unit square and input
positions stay strictly increasing.

## Import a LUT

**Import .cube LUT** validates and embeds the file text in the document. It
therefore survives save/reopen, clipboard operations and generated Dart without
an external file dependency. Library authors can still use the relative `asset`
form. An invalid import shows its error and leaves the document unchanged.

The supported contract is a 3D `.cube` table with 2–64 samples per axis and at
most 4 MiB of UTF-8 text. Input and output are encoded, non-linear sRGB in the
unit cube. Only `DOMAIN_MIN 0 0 0` and `DOMAIN_MAX 1 1 1` are accepted. Fluvie
applies no extra transfer function. Values are sampled with trilinear filtering;
LUT intensity zero returns the original child exactly.

Shader programs and lookup images warm before the graded composition mounts.
The canvas displays preparation, failure and retry states instead of silently
pretending a failed LUT applied. Export uses the same preparation path.

## Read scopes

The histogram shows RGB distributions. The waveform shows luminance by
horizontal position. The vectorscope shows Cb/Cr chroma density, with neutral
colours at its centre. Transparent pixels are excluded. Scopes read the existing
settled preview stage before editor handles, at up to 320 pixels across. Requests
are throttled to ten per second and cached by document render digest and frame;
fast scrubbing coalesces to the latest settled frame.

Scopes are read-only and never change a document digest or appear in export.
They describe preview pixels, so a reduced-resolution preview can differ slightly
from full-resolution delivery. GPU golden baselines are pinned to Linux;
software rasterizers and encoders need not produce identical bytes across machines.

## Dart authoring

<!-- code-excerpt "examples/gallery/lib/snippets/spec_serialization_snippets.dart (colour-grade)" -->
```dart
return child.effects([
  Effect.grade(exposure: 0.2, contrast: 1.08, intensity: 0.6),
  Effect.curves(master: ToneCurve.fromPoints(const [(0, 0), (0.5, 0.55), (1, 1)])),
]);
```

See [Effects](editor-effects.md) for stack order, enabling and keyframe controls.
