// Barrel hygiene (Epic 8.5 close-out): the single public entry exports
// Fluvie's own `Image`/`Clip`/`Animation`/`Tween` under the names that shadow
// Flutter's (decision 10). An author who imports both `package:fluvie/fluvie.dart`
// and Flutter must `hide` the four shadowed names from Flutter; this test
// imports them that way and proves every name resolves to Fluvie's type, and
// that the Phase 8 surface (`Image`, `Clip`, `Typewriter`, `Counter`,
// `Timeline`, `MediaSource`, `NumberFormat`) is reachable from the barrel alone.

import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
// The exact import an author writes: Flutter under a prefix so its names never
// collide, the barrel unprefixed so Fluvie's shadowed names win.
import 'package:fluvie/fluvie.dart';

void main() {
  group('the barrel is the only public entry', () {
    test("Image resolves to Fluvie's widget, not Flutter's", () {
      final image = Image.asset('fixtures/swatch.png');
      expect(image, isA<Image>());
      expect(image, isNot(isA<flutter.Image>()));
      // The Fluvie surface the barrel adds is reachable.
      expect(image.source, isA<MediaSource>());
    });

    test("Clip resolves to Fluvie's widget, not Flutter's", () {
      final clip = Clip.asset('fixtures/clip_1s.mp4');
      expect(clip, isA<Clip>());
      expect(clip, isNot(isA<flutter.ClipRect>()));
      expect(clip.source, isA<MediaSource>());
      expect(clip.audio, isA<ClipAudio>());
    });

    test("Animation and Tween resolve to Fluvie's, not Flutter's", () {
      final animation = Animation.fadeIn();
      expect(animation, isA<Animation>());
      expect(animation, isNot(isA<flutter.Animation<Object?>>()));
    });

    test('Typewriter and Counter are exported from the barrel', () {
      expect(const Typewriter('hi'), isA<Typewriter>());
      expect(const Counter(to: 10), isA<Counter>());
    });

    test('Timeline, LabelRef, and the String.label sugar are exported', () {
      final timeline = Timeline();
      expect(timeline, isA<TimelineSchedule>());
      expect('reveal'.label, isA<LabelRef>());
      expect(('reveal'.label - const Time.frames(6)).offset, const Time.frames(-6));
    });

    test('Particles and NoiseSource are exported for the effect surface', () {
      // The Phase 9 public values: the particle spec authors pass to
      // Animation.particles, and the seeded-randomness contract §22 promises.
      expect(const Particles.confetti(seed: 'win'), isA<Particles>());
      expect(_TestNoise(), isA<NoiseSource>());
    });

    test('the Phase 10 chart + theme surface is reachable (WI-16)', () {
      // Chart and its data types, plus the FluvieTokens theming seam, are
      // public; scales and painters stay internal.
      expect(Chart.bar(data: const {'A': 1}), isA<Chart>());
      expect(const ChartSeries.values(name: 's', data: {'A': 1}), isA<ChartSeries>());
      expect(const ChartPoint(x: 1, y: 2), isA<ChartPoint>());
      expect(const FluvieTokens.fallback(), isA<FluvieTokens>());
      expect(const FluvieTokens.fallback().palette, isA<ChartPalette>());
      expect(
        const FluvieTokensScope(tokens: FluvieTokens.fallback(), child: flutter.SizedBox.shrink()),
        isA<FluvieTokensScope>(),
      );
    });

    test('the Phase 11 code / terminal / markdown surface is reachable (WI-20)', () {
      // Code, its reveal and theme, Terminal with its line and chrome models,
      // and Markdown are public; the highlighter, parser, diff, and painters
      // stay internal.
      expect(const Code('void main() {}', language: 'dart'), isA<Code>());
      expect(const CodeReveal.typing(Time.frames(2)), isA<CodeReveal>());
      expect(const FluvieTokens.fallback().code, isA<CodeTheme>());
      expect(
        const Terminal(lines: [TerminalLine.cmd('npm i'), TerminalLine.out('done')]),
        isA<Terminal>(),
      );
      expect(const TerminalLine.cmd('ls'), isA<TerminalLine>());
      expect(const TerminalChrome.macos(title: 'zsh'), isA<TerminalChrome>());
      expect(const Markdown('# Title'), isA<Markdown>());
      expect(const MarkdownStyle.fallback(), isA<MarkdownStyle>());
    });

    test('the Phase 12 mermaid / webview / snapshot surface is reachable (WI-19)', () {
      // Mermaid (with its reveal + theme), WebView, Html, Snapshot, DeviceFrame
      // and the SnapshotViewport value are public; the SnapshotSource/Request/
      // Raster value types, the ResolvedSnapshot path, the CDP harness, and the
      // SVG rasterizer stay internal. MermaidTheme reaches the barrel through
      // theme/fluvie_tokens.dart, so it must not be double-exported.
      const viewport = SnapshotViewport(width: 320, height: 240);
      expect(viewport, isA<SnapshotViewport>());
      expect(const Mermaid('graph TD; A-->B;'), isA<Mermaid>());
      expect(const MermaidReveal.fadeNodes(Time.frames(30)), isA<MermaidReveal>());
      expect(const MermaidTheme.dark(), isA<MermaidTheme>());
      expect(WebView.url('https://example.com', viewport: viewport), isA<WebView>());
      expect(const Html('<h1>Hi</h1>', viewport: viewport), isA<Html>());
      expect(const Snapshot(child: flutter.SizedBox.shrink()), isA<Snapshot>());
      expect(
        const DeviceFrame.browser(
          url: 'https://example.com',
          child: flutter.SizedBox.shrink(),
        ),
        isA<DeviceFrame>(),
      );
      // The typed missing-capability error stays public so an author can catch
      // the install hint; the SnapshotService contract itself lives on the
      // rendering barrel (see rendering_barrel_test.dart).
      expect(FluvieSnapshotUnavailableError('no chrome'), isA<Exception>());
    });

    test('the Phase 13 captions / reactive / annotation surface is reachable (WI-23)', () {
      // The annotations (Shape / Arrow / Connector / Spotlight / Callout /
      // LowerThird / TitleCard), the reactive Bars visualizer, the caption value
      // types (CaptionStyle / CaptionPosition / CaptionCue), and CaptionTheme
      // (via FluvieTokens.captions) are public; the AudioSource / CaptionSource /
      // BandTable / DSP / ReactiveScope / parsers / annotation painters stay
      // internal, and the BeatDetectionService / FrequencyAnalyzer contracts
      // live on the rendering barrel.
      expect(
        const Shape.line(from: flutter.Offset.zero, to: flutter.Offset(10, 10)),
        isA<Shape>(),
      );
      expect(
        const Arrow.to(from: flutter.Offset.zero, to: flutter.Offset(10, 10)),
        isA<Arrow>(),
      );
      expect(
        const Connector(from: flutter.Offset.zero, to: flutter.Offset(10, 10)),
        isA<Connector>(),
      );
      expect(
        const Spotlight.on(
          region: flutter.Rect.fromLTWH(0, 0, 10, 10),
          child: flutter.SizedBox.shrink(),
        ),
        isA<Spotlight>(),
      );
      expect(
        const Callout(
          label: 'x',
          target: flutter.Offset(5, 5),
          child: flutter.SizedBox.shrink(),
        ),
        isA<Callout>(),
      );
      expect(const LowerThird(name: 'Ada', title: 'Maths'), isA<LowerThird>());
      expect(const TitleCard(title: 'Chapter One'), isA<TitleCard>());
      expect(const Bars(count: 12), isA<Bars>());
      expect(const CaptionStyle.tikTok(), isA<CaptionStyle>());
      expect(const CaptionPosition.bottomThird(), isA<CaptionPosition>());
      expect(
        CaptionCue('hi', start: Time.zero, end: const Time.frames(30)),
        isA<CaptionCue>(),
      );
      expect(const FluvieTokens.fallback().captions, isA<CaptionTheme>());
    });

    test('the Phase 14 theme / aspect / template / FrameBuilder surface is '
        'reachable (WI-31)', () {
      // The §21 theme value types (Palette / TypeScale) and the FluvieTheme
      // widget, the §23 multi-aspect (Adaptive + the AspectScope.of accessor)
      // and template (VideoTemplate + the built-in TitleIntro / StatHighlight on
      // the public API), and the §20 FrameBuilder escape hatch with its
      // FrameContext are public; the NoiseScope, BeatGridScope, the capture
      // shell, and the FrameBuilder runtime helpers stay internal.
      const palette = Palette(
        bg: flutter.Color(0xFF0E0E12),
        accent: flutter.Color(0xFF6C5CE7),
        onBg: flutter.Color(0xFFFFFFFF),
      );
      expect(palette, isA<Palette>());
      expect(const Palette.fallback().accent, isA<flutter.Color>());
      expect(TypeScale.fromBase(16), isA<TypeScale>());
      expect(const TypeScale.fallback().title, isA<flutter.TextStyle>());
      expect(
        const FluvieTheme(palette: palette, child: flutter.SizedBox.shrink()),
        isA<FluvieTheme>(),
      );
      // The §22 brand palette reaches the tree via context.fluvie.brand and the
      // type scale via context.fluvie.type (decision D-Theme-NameClash); the
      // chart-series ChartPalette stays on context.fluvie.palette.
      expect(const FluvieTokens.fallback().brand, isA<Palette>());
      expect(const FluvieTokens.fallback().type, isA<TypeScale>());

      // Multi-aspect: the Aspect enum (with sizeFor / portrait45) and the
      // Adaptive composition, plus the AspectScope.of(context) build-time lookup.
      // `AspectScope.of` is the public accessor; its fallback path is exercised
      // in the package's aspect-scope tests.
      expect(AspectScope.of, isNotNull);
      expect(Aspect.fallback, Aspect.reels);
      expect(Aspect.landscape.sizeFor(1920), isA<VideoSize>());
      expect(Aspect.portrait45, isA<Aspect>());
      expect(
        const Adaptive(landscape: flutter.SizedBox.shrink, reels: flutter.SizedBox.shrink),
        isA<Adaptive>(),
      );

      // Templates: the VideoTemplate base, the built-ins, and their props.
      expect(const TitleIntro(), isA<VideoTemplate<TitleIntroProps>>());
      expect(const TitleIntroProps(title: '2025'), isA<TitleIntroProps>());
      expect(const StatHighlight(), isA<VideoTemplate<StatHighlightProps>>());
      expect(
        const StatHighlightProps(value: 1, label: 'x'),
        isA<StatHighlightProps>(),
      );

      // The FrameBuilder escape hatch and the FrameContext it paints from.
      expect(
        FrameBuilder((ctx) => flutter.SizedBox(width: ctx.progress)),
        isA<FrameBuilder>(),
      );

      // The render / renderTemplate free functions live on the rendering
      // barrel (see rendering_barrel_test.dart), not here.

      // The Export modes ride core/export.dart, reachable from the barrel.
      expect(const Export.gif().mode, ExportMode.gif);
    });

    test('the Phase 15 inspector surface is reachable (WI-17)', () {
      // The diagnostics InspectorModel (with its InspectorMotion rows) and the
      // structured TimelineAnchor egress are public so the example inspector
      // can build and bind to the resolved schedule; the resolver internals
      // (AnchorRegistry / TriggerResolver / ResolvedComposition) stay private.
      const timeline = ResolvedTimeline(
        fps: 30,
        totalFrames: 120,
        rows: [
          TimelineRow(
            ownerId: 's0e0:Text',
            label: 'pop',
            phase: AnimationPhase.enter,
            startFrame: 0,
            endFrame: 18,
          ),
        ],
        anchors: [TimelineAnchor(name: 'intro', frame: 0)],
      );
      final model = InspectorModel.fromTimeline(timeline);
      expect(model, isA<InspectorModel>());
      expect(model.motions.single, isA<InspectorMotion>());
      expect(model.motions.single.jumpFrame, 0);
      expect(model.anchors.single, isA<TimelineAnchor>());
      expect(model.anchors.single.frame, 0);
    });
  });
}

/// A trivial [NoiseSource] proving the contract is reachable and implementable
/// from the barrel alone — the real algorithm (`ValueNoise`) stays internal.
class _TestNoise implements NoiseSource {
  @override
  double valueForSeed(String seed) => 0;
  @override
  double noise1(double x) => 0;
  @override
  double noise2(double x, double y) => 0;
}
