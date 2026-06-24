# Theming

Brand a video from one palette and one type scale. Wrap a subtree in a
`FluvieTheme` and its descendants read the brand colors and the type ladder from
`context.fluvie`. Lesson 11 sets a brand and a scale once:

<!-- code-excerpt "examples/gallery/lib/lessons/11_templates_and_aspects.dart (theme)" -->
```dart
const _brand = Palette(
  bg: Color(0xFF0E1116),
  accent: Color(0xFF55EFC4),
  onBg: Color(0xFFE6EDF3),
);
final _type = TypeScale.fromBase(40, ratio: 1.3);
```

Text reads those tokens at the call site, picking the display role and the brand
accent:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (themed-text)" -->
```dart
Builder(
  builder: (context) => Text(
    'One definition,\nmany formats',
    textAlign: TextAlign.center,
    style: context.fluvie.type.display.copyWith(color: context.fluvie.brand.accent),
  ).animate([Animation.pop()]),
);
```

The rest of this page covers the palette, the type scale, the three token
groups, and the precedence rule.

## FluvieTheme

`FluvieTheme` carries three optional tokens and a child. Each token you omit
inherits from the nearest theme above, so themes nest and an inner theme
overrides only the fields it sets:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (fluvie-theme)" -->
```dart
FluvieTheme(
  palette: const Palette(
    bg: Color(0xFF0E1116),
    accent: Color(0xFF55EFC4),
    onBg: Color(0xFFE6EDF3),
  ),
  type: TypeScale.fromBase(40, ratio: 1.3),
  motion: const Defaults(duration: Time.seconds(0.5), ease: Ease.out),
  child: video,
);
```

Wrap a whole `Video` to brand everything, or wrap one scene to brand a section.
Every element that already reads `context.fluvie` (charts, `Code`, `Mermaid`,
captions, annotations) picks the brand up with no change at the call site.

## The palette

`Palette` is the brand color set. It carries the backdrop, the accent, the
foreground that reads on the backdrop, and an optional raised-surface pair:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (palette)" -->
```dart
const Palette(
  bg: Color(0xFF0E1116), // the backdrop
  accent: Color(0xFF55EFC4), // the brand color for emphasis
  onBg: Color(0xFFE6EDF3), // the foreground that reads on bg
  surface: Color(0xFF1A1F26), // optional: a raised-panel color
  onSurface: Color(0xFFE6EDF3), // optional: the ink on a surface
);
```

Read it via `context.fluvie.brand`:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (brand-access)" -->
```dart
context.fluvie.brand.bg,
context.fluvie.brand.accent,
context.fluvie.brand.onBg,
```

One name to keep straight: `context.fluvie.brand` is this brand palette.
`context.fluvie.palette` is a different thing, the ordered chart-series colors a
chart cycles through. For brand colors, reach for `.brand`.

## The type scale

`TypeScale.fromBase` derives five text roles from one base size and a ratio.
Each role steps the body size up or down by the ratio:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (type-scale)" -->
```dart
TypeScale.fromBase(40, ratio: 1.3);
```

The five roles, largest to smallest:

<!-- code-excerpt "examples/gallery/lib/snippets/phase_11_snippets.dart (type-roles)" -->
```dart
context.fluvie.type.display, // hero numbers and full-screen statements
context.fluvie.type.title, // scene headings and the main on-screen line
context.fluvie.type.headline, // a secondary line above body copy
context.fluvie.type.body, // running text and labels, at the base size
context.fluvie.type.caption, // footnotes, attributions, fine print
```

A role carries only a font size and a weight, never a font family or a color.
That keeps it composable: apply a role and add a color at the call site with
`copyWith`, the way the themed text above does.

## The three token groups

`context.fluvie` exposes three theme groups:

- `context.fluvie.brand` is the `Palette` of brand colors.
- `context.fluvie.type` is the `TypeScale` of text roles.
- `context.fluvie.motion` is the `Defaults` for animation duration and easing.

The `motion` group folds into the animation cascade, so a theme can set the
default duration and easing for every animation under it without touching each
one.

## Precedence

When more than one source sets a value, the most specific wins. The order, most
specific first:

1. An explicit property on the element. A color or duration you write at the call
   site always wins.
2. The nearest `FluvieTheme`. Its tokens apply where the element did not set one.
3. The package fallback. A real dark-neutral palette, a 16-pixel type scale, and
   the built-in motion defaults, so an unthemed subtree still has usable tokens.

For motion the cascade has one more rung: an animation-local default beats a
`Scene` default, which beats a `Video` default, which beats the theme's `motion`,
which beats the package. So you set a broad default once in the theme and
override it for one animation when you need to.

This is why a theme is opt-in and never surprising. Text stays plain until you
read a token, an element keeps any color you pass it, and a video with no theme
renders exactly as it did before, against the package fallback.

## Where to next

- [Multi-aspect](multi-aspect.md): brand every aspect of a video from one theme.
- [Charts and data](../guides/charts-and-data.md): the chart-series
  `context.fluvie.palette`, the other palette a theme carries.
- [Templates](templates.md): brand a data-driven template per render with a
  `Palette` from your props.
