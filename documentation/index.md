# Fluvie

**You write widgets. Fluvie shoots the film.**

Fluvie renders a declarative Flutter tree to a real video file (MP4 via FFmpeg).
You describe what the video is, and Fluvie works out when everything happens,
frame by frame. Think of it as a small film studio that already speaks Flutter:
you direct, Fluvie keeps continuity, and FFmpeg runs the projector.

## Pick your seat

- **New here?** Install Fluvie, render your first video, and learn the core ideas.
  Start with [Installation](getting-started/installation.md).
- **Building something?** Reach for the task [guides](guides/animating-elements.md):
  animation, audio, charts, code scenes, theming, and export.
- **Just need a recipe?** The [cookbook](cookbook.md) has short answers to one task each.
- **Want AI to direct?** See [AI and MCP](guides/ai-and-mcp.md): author a video from a
  prompt, run it locally, or point Claude at it.

## Why people like it

- **Declarative.** Compose scenes and elements like any Flutter screen.
- **On-device or server.** Render in the browser, on a phone, from the command
  line, an HTTP API, or an MCP server. No display required.
- **Cacheable.** The same input re-renders from cache, so golden tests and batch
  rendering stay fast.
- **Conversational.** Ask for a video in plain language and get a spec back.

## The rest of the ecosystem

This site is the manual. Here is the rest of the building.

- [fluvie.dev](https://fluvie.dev): the one-screen introduction.
- [demo.fluvie.dev](https://demo.fluvie.dev): try Fluvie live in the browser and render a clip.
- [mcp.fluvie.dev](https://mcp.fluvie.dev): the hosted MCP server, so an AI assistant can make videos for you.
- [pub.dev/packages/fluvie](https://pub.dev/packages/fluvie): the package.

## Where to next

- [Installation](getting-started/installation.md): set up Flutter and FFmpeg.
- [Your first video](getting-started/your-first-video.md): lesson 01, start to finish.
- [Core concepts](getting-started/core-concepts.md): the mental model in five minutes.
