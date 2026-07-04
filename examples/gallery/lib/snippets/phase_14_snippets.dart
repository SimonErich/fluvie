// Compiled, tested snippets for the export, templates, multi-aspect, and
// frame-builder docs. They live here, not hand-typed in
// Markdown, so the documentation never drifts from a real API. Each
// `#docregion` flows into one fence via a `<!-- code-excerpt -->` marker.

// FrameBuilder and FrameContext are @experimental by design; the frame-builder
// snippets exist to document them, so the experimental-use
// warning is expected here. The export-menu snippets deliberately spell out the
// default quality/fps so the docs read as a full reference, which trips
// avoid_redundant_argument_values.
// ignore_for_file: experimental_member_use, avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

/// The four export modes, each pure config data carried on `Video.export`.
/// The render pipeline dispatches on the mode you pick.
// #docregion export-modes
Export sharable() => const Export.mp4(quality: Quality.max); // H.264 MP4, CRF 14
Export loopingThumb() => const Export.gif(fps: 12); // animated GIF at 12 fps
Export forCompositing() => const Export.imageSequence(); // one PNG per frame
Export overlay() => const Export.transparent(); // WebM with an alpha channel
// #enddocregion export-modes

/// The four MP4 quality levels, lowest to highest. Each maps to a
/// constant-rate factor: a lower CRF is a bigger, less-compressed file.
List<Export> mp4Qualities() => const [
  // #docregion export-mp4-quality
  Export.mp4(quality: Quality.low), // CRF 28, smallest file, visible compression
  Export.mp4(quality: Quality.medium), // CRF 23, a rough-cut trade-off
  Export.mp4(quality: Quality.high), // CRF 18, the default for published videos
  Export.mp4(quality: Quality.max), // CRF 14, near-lossless, the largest file
  // #enddocregion export-mp4-quality
];

/// The GIF sample rates: `fps` thins the frames, since a GIF rarely needs the
/// full rate.
List<Export> gifRates() => const [
  // #docregion export-gif-fps
  Export.gif(fps: 15), // the default sample rate
  Export.gif(fps: 12), // a smaller, choppier loop
  // #enddocregion export-gif-fps
];

/// One lossless PNG per frame, for a downstream compositing pipeline.
Export pngSequence() =>
    // #docregion export-image-sequence
    const Export.imageSequence(); // one PNG per frame, into the output directory
// #enddocregion export-image-sequence

/// A WebM with an alpha plane, to layer the video over other footage.
Export alphaOverlay() =>
    // #docregion export-transparent
    const Export.transparent(); // VP9 WebM with a yuva420p alpha plane
// #enddocregion export-transparent

/// A video tagged with an export mode and a poster frame. `poster` names the
/// `Time` the still is grabbed from; `export` picks the container.
// #docregion export-poster
Video exportedReel() => Video(
  size: VideoSize.reels,
  export: const Export.mp4(quality: Quality.max), // near-lossless, CRF 14
  poster: const Time.seconds(1.5), // the thumbnail frame
  scenes: [
    Scene.centered(
      duration: const Time.seconds(3),
      background: Background.color(const Color(0xFF0E1116)),
      child: const Text('Exported', style: TextStyle(fontSize: 72, color: Color(0xFFE6EDF3))),
    ),
  ],
);
// #enddocregion export-poster

/// A user-defined template: one `build` turns a `Props` value into a [Video].
/// The built-ins (`TitleIntro`, `StatHighlight`) extend the same base.
// #docregion template-define
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
// #enddocregion template-define

/// Data-driven batch rendering: map each row onto its `Props` and render the
/// same template once per row. The same `Props` always render the same frames.
// #docregion template-batch
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
// #enddocregion template-batch

/// Rendering one fixed-size composition for one aspect. `render` re-derives the
/// canvas from the aspect, so the same definition fans out to many formats.
// #docregion render-aspect
Future<void> renderForAspects({
  required Widget composition,
  required RenderService service,
  required ShellMount pumpWidget,
  required ShellFramePump pumpFrame,
}) async {
  for (final aspect in [Aspect.reels, Aspect.square, Aspect.landscape, Aspect.portrait45]) {
    await render(
      composition: composition,
      aspect: aspect,
      frameCount: 90,
      outDir: Directory('out/${aspect.name}'),
      service: service,
      pumpWidget: pumpWidget,
      pumpFrame: pumpFrame,
    );
  }
}
// #enddocregion render-aspect

/// `AspectScope.of(context)` reads the rendered aspect at build time, so an
/// element can branch its own layout without an `Adaptive` wrapper.
// #docregion aspect-of
Widget headlineForAspect() => Builder(
  builder: (context) {
    final wide = AspectScope.of(context) == Aspect.landscape;
    return Text(
      wide ? 'Wide cut' : 'Tall cut',
      style: const TextStyle(fontSize: 64, color: Color(0xFFE6EDF3)),
    );
  },
);
// #enddocregion aspect-of

/// `FrameBuilder` is the @experimental escape hatch: it hands you a
/// `FrameContext` every frame, and your builder returns the widget to paint.
/// Read `progress`, `frame`, `fps`, the seeded `noise`, and the analysed audio.
// #docregion frame-builder
Widget sweepingBar() => FrameBuilder((ctx) {
  final reach = ctx.progress; // 0..1 across this element's window
  return Align(
    alignment: Alignment(-1 + reach * 2, 0),
    child: const SizedBox(
      width: 24,
      height: 240,
      child: ColoredBox(color: Color(0xFF55EFC4)),
    ),
  );
});
// #enddocregion frame-builder

/// A `FrameBuilder` reading seeded noise and the analysed bass band. Both are
/// precomputed before frame 0, so the builder stays a pure function of the
/// frame (the determinism rule).
// #docregion frame-builder-audio
Widget pulsingChip(Anchor music) => FrameBuilder((ctx) {
  final wobble = ctx.noise('chip-${ctx.frame ~/ 6}') * 0.1; // seeded, reproducible
  final beat = ctx.audio(music); // analysed bass energy, 0..1
  return Transform.scale(
    scale: 1 + beat * 0.4 + wobble,
    child: const SizedBox(
      width: 120,
      height: 120,
      child: ColoredBox(color: Color(0xFF7C5CFF)),
    ),
  );
});
// #enddocregion frame-builder-audio
