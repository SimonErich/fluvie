# Fluvie documentation

New here? Start with [your-first-video](getting-started/your-first-video.md).
Pages ship with the phase that builds their feature; this map shows what
already exists and what is coming.

## Map

| Section | Page | Status |
| --- | --- | --- |
| getting-started/ | [installation](getting-started/installation.md) | shipped |
| getting-started/ | [your-first-video](getting-started/your-first-video.md) | shipped |
| getting-started/ | [core-concepts](getting-started/core-concepts.md) | shipped |
| guides/ | [layouts](guides/layouts.md) | shipped |
| guides/ | [backgrounds-and-gradients](guides/backgrounds-and-gradients.md) | shipped |
| guides/ | [timing-and-triggers](guides/timing-and-triggers.md) | draft, grows per phase |
| guides/ | [animating-elements](guides/animating-elements.md) | shipped |
| guides/ | [scenes-and-transitions](guides/scenes-and-transitions.md) | shipped |
| guides/ | [text-and-typography](guides/text-and-typography.md) · [images-and-video-clips](guides/images-and-video-clips.md) | shipped |
| guides/ | [charts-and-data](guides/charts-and-data.md) | shipped |
| guides/ | [code-and-terminal-videos](guides/code-and-terminal-videos.md) | shipped |
| guides/ | [diagrams-and-webviews](guides/diagrams-and-webviews.md) | shipped |
| guides/ | [audio-and-captions](guides/audio-and-captions.md) | shipped |
| guides/ | [exporting-your-video](guides/exporting-your-video.md) | shipped |
| guides/ | [authoring-with-specs](guides/authoring-with-specs.md) | shipped |
| guides/ | [ai-and-mcp](guides/ai-and-mcp.md) | shipped |
| guides/ | [rendering-on-a-server](guides/rendering-on-a-server.md) | shipped |
| guides/ | [on-device-mobile-rendering](guides/on-device-mobile-rendering.md) | shipped |
| (root) | [cookbook](cookbook.md) | shipped |
| advanced/ | custom-animations · [timeline-orchestration](advanced/timeline-orchestration.md) · [frame-builder](advanced/frame-builder.md) · [shaders-and-effects](advanced/shaders-and-effects.md) · [templates](advanced/templates.md) · [multi-aspect](advanced/multi-aspect.md) · [theming](advanced/theming.md) · [performance](advanced/performance.md) | performance + frame-builder + shaders-and-effects + templates + multi-aspect + theming + timeline-orchestration shipped; custom-animations per page |
| reference/ | [cheatsheet](reference/cheatsheet.md) | shipped, living |
| reference/ | [migration](reference/migration.md) · [faq](reference/faq.md) | shipped |
| contributing/ | [overview](contributing/overview.md) · [testing](contributing/testing.md) · [coverage](contributing/coverage.md) | shipped |

## House rules for every page

Short sentences. Active voice. You-form. Lead with a runnable example. One
page answers one question. No em-dashes, no marketing vocabulary. End with a
"Where to next" footer. Dart snippets come from compiled lesson files via
code-excerpt directives, never hand-typed.

## Where to next

- [Installation](getting-started/installation.md): set up Flutter and FFmpeg.
- [Your first video](getting-started/your-first-video.md): lesson 01, start
  to finish.
- [Images and video clips](guides/images-and-video-clips.md): photos and
  embedded video, pre-resolved before the frame loop.
- [Charts and data](guides/charts-and-data.md): bar, line, area, pie, donut,
  and scatter charts that reveal themselves from your data.
- [Code and terminal videos](guides/code-and-terminal-videos.md): typed,
  highlighted code, an animated diff, a terminal session, and Markdown.
- [Diagrams and web pages](guides/diagrams-and-webviews.md): Mermaid diagrams,
  web pages, and Flutter subtrees rasterized once and painted every frame.
- [Audio and captions](guides/audio-and-captions.md): a music bed, beat-reactive
  motion analysed before frame 0, subtitles, and annotations.
- [Exporting your video](guides/exporting-your-video.md): MP4, GIF, image
  sequence, transparent WebM, a poster frame, and the command-line renderer.
- [Authoring with specs](guides/authoring-with-specs.md): save a video as JSON,
  load it back, and generate one from a prompt with an LLM.
- [Rendering on a server](guides/rendering-on-a-server.md): the HTTP API that
  renders videos to files, with local or S3 storage and scheduled cleanup.
- [Templates](advanced/templates.md): render one definition per data row.
- [Multi-aspect](advanced/multi-aspect.md): one definition rendered to reels,
  square, landscape, and portrait.
- [Theming](advanced/theming.md): brand a video from one palette and type scale.
- [The FrameBuilder escape hatch](advanced/frame-builder.md): the experimental
  frame-clock builder for when no preset fits.
- [Shaders and effects](advanced/shaders-and-effects.md): grain, particles,
  parallax, and fragment shaders, all in one animate list.
- [Animating elements](guides/animating-elements.md): the one motion list,
  the presets, triggers, and stagger.
- [Performance](advanced/performance.md): the frame cache, content-hash media
  caching, and the habits that keep a render fast.
- [Cheatsheet](reference/cheatsheet.md): the whole public surface on one page.
- [Migration](reference/migration.md) and [FAQ](reference/faq.md): old names
  mapped to new, and the questions a new user asks first.
