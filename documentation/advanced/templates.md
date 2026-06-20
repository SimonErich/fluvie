# Templates

Describe a video shape once, then render it for many inputs. A `VideoTemplate`
turns a `Props` value into a `Video`, so the same definition makes a personalized
intro per user or a stat reel per metric. Lesson 11 reuses the built-in
`StatHighlight` template and lifts its scene into a reel:

<!-- code-excerpt "example/lib/lessons/11_templates_and_aspects.dart (template)" -->
```dart
Scene _statCardScene() => const StatHighlight().build(_stat).scenes.single;
```

The props feeding it are plain data:

<!-- code-excerpt "example/lib/lessons/11_templates_and_aspects.dart (stat-props)" -->
```dart
const _stat = StatHighlightProps(value: 48230, label: 'minutes listened');
```

Change `_stat` and the same template builds a different card. The rest of this
page covers writing your own template, the two built-ins, and rendering a batch.

## Writing a template

Subclass `VideoTemplate<Props>` and implement `build`. The `build` is a pure
function of its props: it reads the value and returns a `Video`, with no IO and
no wall-clock:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (template-define)" -->
```dart
class GreetingProps {
  const GreetingProps({required this.name});
  final String name;
}

class GreetingTemplate extends VideoTemplate<GreetingProps> {
  const GreetingTemplate();

  @override
  Video build(GreetingProps props) => Video(
    size: VideoSize.reels,
    scenes: [
      Scene.centered(
        duration: const Time.seconds(3),
        background: Background.color(const Color(0xFF0E1116)),
        child: Text(
          'Hi ${props.name}',
          style: const TextStyle(fontSize: 80, color: Color(0xFF55EFC4)),
        ).animate([Animation.pop()]),
      ),
    ],
  );
}
```

A template is `const` and holds no state. Every choice flows through the props,
which keeps the definition a pure function of its input. Make your `Props`
value-equal (immutable, with `==` and `hashCode` by field), so two equal props
compare equal and the cache can trust them.

## The built-in templates

Two templates ship on the public API. Each is built only on the public element
API, so it doubles as a worked example of a `VideoTemplate`.

`TitleIntro` is a centered title that pops in, with an optional subtitle that
slides in after:

<!-- code-excerpt "example/lib/snippets/phase_11_snippets.dart (title-props)" -->
```dart
const TitleIntroProps(title: '2025', subtitle: 'Year in review');
```

`StatHighlight` is a `Counter` headline counting up to a value, with its label
beneath:

<!-- code-excerpt "example/lib/snippets/phase_11_snippets.dart (stat-props)" -->
```dart
const StatHighlightProps(value: 48230, label: 'minutes listened');
```

Both props carry an optional `accent` color and `background` color, so you brand
a card without rewriting it. Read the source of either as a starting point for
your own template.

## Rendering a template

`renderTemplate` builds `template.build(props)` and runs the result through the
same offline capture path that `render(video, aspect:)` uses. It is a separate
free function from `render`, because Dart has no overloading. To render a batch,
map each data row onto its props and call `renderTemplate` once per row:

<!-- code-excerpt "example/lib/snippets/phase_14_snippets.dart (template-batch)" -->
```dart
Future<void> renderGreetings({
  required List<String> names,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
}) async {
  for (final name in names) {
    await renderTemplate(
      const GreetingTemplate(),
      props: GreetingProps(name: name),
      frameCount: 90,
      outDir: Directory('out/$name'),
      service: service,
      pumpWidget: pumpWidget,
      pumpFrame: pumpFrame,
    );
  }
}
```

`renderTemplate` defaults `aspect` to `Aspect.reels`, so a template renders
vertical without a per-call aspect. Pass another aspect to fan one template out
across formats. The `service`, `pumpWidget`, and `pumpFrame` are the host's
render wiring; the example app and the CLI supply them for you.

## Same props, same frames

The headline contract: the same template rendered for the same props twice
produces byte-identical frames. The render path proves this with a test that
renders three cards from a data list and compares bytes.

This holds because `build` is a pure function of its props and the capture
pipeline is deterministic. The same props build the same tree, the same tree
captures the same pixels, and value-equal props let the frame cache share work
across renders. Different props produce different frames, as you would expect.
Pass a different `value` and the count changes; pass an equal `Props` and you
get the exact same bytes.

This is what makes data-driven batch rendering safe. Render a thousand
personalized intros from a thousand rows, re-run the batch tomorrow, and every
unchanged row produces the same file it did today.

## Where to next

- [Multi-aspect](multi-aspect.md): fan one template out to reels, square,
  landscape, and portrait with the same props.
- [Exporting your video](../guides/exporting-your-video.md): pick the container
  each rendered template writes.
- [Determinism and caching](determinism-and-caching.md): why the same props
  always render the same frames.
