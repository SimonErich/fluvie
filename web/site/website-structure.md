# Fluvie marketing site, structure brief

> Status: implemented. This brief was built (via Claude Design) into
> [`index.html`](index.html), the static page served at fluvie.dev. Keep the two in
> sync; this doc stays the reference for structure, motion, and accessibility, and the
> source of truth when the page changes. See [`MAINTAINING.md`](MAINTAINING.md).

Paste this into Claude Design together with your brand CI. This document owns the
**structure, content, motion, microinteractions, and accessibility** of the
fluvie.dev landing page. It does **not** own color or type: your CI does. There
are no hex values, no font names, and no spacing tokens here on purpose. Where
you read "emphasis", "lead surface", or "accent", map it to your CI.

> One small exception: the Dart code samples below contain `Color(0xFF...)`
> literals. Those are example values inside the sample, part of the real API, not
> the page palette. Render them as code, do not lift them into the design.

## How to use this brief

- Build one long-scroll page. Read scrolling down as scrubbing forward through a
  film. The whole page is a reel.
- Serve three people at once (see [Personas](#personas-the-three-people-we-build-for)):
  a cold visitor with zero context, a Flutter dev who got Fluvie recommended, and
  an existing user hunting one doc.
- Every section has one job, one question it answers. If a section answers two
  questions, split it.
- Each section gets a "special" treatment so the page never reads as plain lists
  and tables. But scannability wins every tie. Personality lives in entrance and
  hover, never in the resting state.
- Accessibility is a gate, not a finish. Every motion has a reduced-motion
  fallback. Everything works by keyboard. Meaning is never carried by color or
  motion alone.

## Voice rules (match these exactly)

The page must sound like the docs: warm, funny, a little cute, and precise.

- Short sentences. Active voice. Second person ("you").
- Lead with a runnable example wherever you can.
- No em-dashes anywhere.
- Banned words: seamless, robust, leverage, powerful (as filler), effortless,
  blazing, unleash. If a sentence needs one of these, the sentence is wrong.
- The film-studio world is on brand: roll camera, shoots the film, pick your
  seat, projector, continuity, clapperboard, the crew. Use it. Do not drown in it.
- The canonical tagline is: **"You write widgets. Fluvie shoots the film."**

## Personas, the three people we build for

1. **The cold visitor.** Landed here by accident. Has never heard of Fluvie. The
   hero has to teach them in seconds, before a single line of code.
2. **The Flutter dev.** Got it recommended, does not know it yet, and is a little
   skeptical of marketing. Wants real widget code early, the "oh, that is clever"
   moment, and the shortest path to trying it.
3. **The existing user.** Already builds with Fluvie. Wants the fastest jump to a
   specific doc, package, or repo, from any scroll depth.

---

## The narrative spine

See it, then understand it, then believe it, then do it, then browse it, then
meet the toolkit, then trust it, then find your way in, then leave through the
right door.

```
0  Sticky nav + skip link
1  Hero: code in, film out
2  The one idea: what, not when
3  The clever bit: triggers, not timecodes
4  The payoff: write one, render a thousand
5  From `fluvie init` to `fluvie render`      (the getting-started)
6  The reel wall: twelve examples
7  The crew: seven packages
8  Open source, on purpose
9  Pick your seat: CLI / HTTP / MCP / live
10 Or just say what you want (AI + MCP)
11 Roll camera: the final router
12 Footer: end credits
```

---

## Section specs

Each section lists: its job, the persona it serves, where it routes, draft copy
in Fluvie's voice, the special treatment, the signature motion, and an
accessibility note.

### 0. Sticky nav + skip link

- **Job:** Let anyone who knows where they are going leave at once, from any depth.
- **Serves / routes:** Everyone, tuned for the expert. Links: Docs
  (docs.fluvie.dev), Demo (demo.fluvie.dev), Packages (jumps to section 7),
  GitHub (github.com/SimonErich/fluvie), and one filled "Get started" button
  (jumps to section 5).
- **Copy:** Wordmark only. On wordmark hover, a quiet tagline whisper: "You write
  widgets. Fluvie shoots the film."
- **Special treatment:** A slim bar, transparent over the hero, that gains a
  backdrop blur and a hairline divider once the hero scrolls past (one threshold,
  not a continuous fade). "Get started" is the only filled element. A thin
  scroll-progress "playhead" rides the bottom edge so long-scroll readers know
  their depth.
- **Motion:** The bar condenses once on crossing the hero boundary (height
  shrinks, labels settle, a single step). An underline slides between items on
  hover and tracks the active section by scroll-spy.
- **Accessibility:** A real `nav`. First focusable element is "Skip to content".
  Focus ring stays visible over both the transparent and blurred states.
  Scroll-spy is exposed with `aria-current`, not motion alone. The progress
  playhead is `aria-hidden` decoration. Reduced motion: the bar swaps state
  instantly, the underline cross-fades.

### 1. Hero: code in, film out

- **Job:** In under five seconds, make a stranger understand: you write Flutter
  widgets, you get a real MP4. Make a dev recognize the code as their own.
- **Serves / routes:** Cold visitor first. Primary "Roll your first video"
  (scrolls to section 5). Secondary "Open the live demo" (demo.fluvie.dev).
- **Copy:**
  - Headline: "You write widgets. Fluvie shoots the film."
  - Lead: "A real Flutter widget tree goes in. A real MP4 comes out. You say what
    the video is. Fluvie works out when everything happens, frame by frame. No
    timeline to scrub by hand. No video editor."
  - Three micro-labels under the lead: "It is code." / "It runs anywhere." /
    "It is a real video file."
- **Special treatment:** A split "film strip" stage. On one side, the real
  lesson-01 source, syntax-highlighted, with the `import 'package:flutter/
  material.dart' hide Animation;` line called out (the wink a Flutter dev
  notices). On the other side, a filmstrip of frames with a preview frame and a
  scrubber, framed like a projector or clapperboard. A perforated connector ties
  the `.animate([fadeIn, pop])` line to the title popping on the preview. Below
  the split, one mono line, `fluvie render hello --out hello.mp4`, with a copy
  button and a small "no display needed" tag. On narrow screens, the panels stack
  code then film, and the connector becomes a downward arrow.
- **Motion (layered by engagement):**
  1. On load, the filmstrip fills left to right while a playhead sweeps the code
     from the `fadeIn` line to the `pop` line. The preview fades and pops in sync,
     then idles on the finished frame with a soft breath.
  2. On hover or scrub, dragging the scrubber steps the preview frame by frame.
     Crossing the `pop` frame highlights the matching code line. Hovering a code
     line highlights the frames it controls. The link runs both ways.
  3. A play or clapper button dramatizes a render: the filmstrip clears, frames
     pour in fast and quantized behind a slim progress bar, and it ends on a
     "no display needed" stamp. A second press replays the fill. Caption:
     "Render it headless."
- **Accessibility:** The code is selectable `pre` text with a language label,
  never an image. Line highlights carry a non-color cue (a left marker or a weight
  change). The scrubber is a real `role="slider"` with `aria-valuemin`,
  `aria-valuemax`, `aria-valuenow`, and an `aria-valuetext` like "frame 7 of 16",
  with full keyboard support (arrows step, Home and End jump). Play is a real
  button named "Render the example video" with an `aria-live="polite"` status
  ("Rendering", then "Done. Identical frames."). Reduced motion: no autoplay fill
  and no pour. Show the finished frame and the full filmstrip at once. Play swaps
  to the end state and announces it. Scrubbing still works, since the user drives
  it. The idle loop auto-pauses off-screen and has a visible Pause control.

### 2. The one idea: what, not when

- **Job:** Deliver the single mental model and kill the wrong assumption (this is
  not a screen recorder and not a video-editor SDK) before any feature talk.
- **Serves / routes:** Cold visitor and dev. Routes to core-concepts
  (docs.fluvie.dev/getting-started/core-concepts).
- **Copy:**
  - Headline: "You bring the what. Fluvie brings the when."
  - Body: "Not a recorder. A renderer. A screen recorder captures whatever
    happened to be on screen. Fluvie computes every frame from your description,
    so frame 412 is the same today, tomorrow, and on your teammate's laptop. You
    declare the scenes and the beats. Fluvie computes the timing. Triggers, not
    frame numbers. Anchors, not stopwatches."
- **Special treatment:** A two-column contrast rendered as a morph, not a table.
  One side, a busy fake timeline with frame numbers and keyframe diamonds. The
  other, a calm stack of human-readable lines ("after the title, float the
  subtitle"). Below, three tight micro-cards: "Describe, do not direct" / "The
  frame is the only clock" / "Same input, same film."
- **Motion:** As the visitor scrolls, the keyframe diamonds slide and dissolve
  into the readable lines (chaos collapses into intent). Hovering a declaration
  line highlights the frames it would have controlled on the old side.
- **Accessibility:** Both states exist in the DOM as text and read top to bottom
  without scrolling. The morph is sugar. The crossed-out "old way" uses
  strikethrough and an icon, never color alone. The pin releases predictably and
  never traps focus or scroll. Reduced motion: render both columns static, side by
  side, no pin, with a one-line text summary of "frame numbers vs triggers".

### 3. The clever bit: triggers, not timecodes

- **Job:** Give the dev the specific payoff (triggers and anchors that re-flow
  when you move a scene), shown, not told.
- **Serves / routes:** The Flutter dev. Routes to core-concepts and the
  cheatsheet (docs.fluvie.dev/reference/cheatsheet).
- **Copy:**
  - Headline: "Triggers, not timecodes."
  - Body: "Say 'after the title lands, float the subtitle.' Fluvie schedules it.
    Move the title earlier and everything downstream follows. No magic frame
    numbers to keep in sync. You never type a frame number."
- **Special treatment:** A two-state code panel with a toggle: "The timeline way"
  (cluttered with hardcoded millisecond values) versus "The Fluvie way"
  (`Trigger.whenEnds(title)`, `previous`, `.show(...)`). Beside it, a live
  mini-timeline in the style of the inspector. A small lever, "move the title
  earlier", visibly desyncs the hardcoded side while the Fluvie side re-flows
  correctly. This is the most persuasive dev interaction on the page.
- **Motion:** Dragging the scene marker animates the dependent blocks re-timing
  live on the Fluvie side. Hovering a code line pulses its bar on the timeline,
  and hovering a bar highlights its line. The toggle cross-dissolves, no layout
  jump. Trigger keywords glow once on first reveal.
- **Accessibility:** The drag has a keyboard equivalent (arrows nudge the scene,
  the result is announced in a polite live region, for example "Subtitle now
  starts after the title"). The toggle is a real `role="tablist"`, keyboard
  reachable. Code and timeline are linked with `aria` relationships. "Broken vs
  correct" carries an icon and a label, not color or motion alone. Reduced motion:
  the re-flow snaps to its end state.

### 4. The payoff: write one, render a thousand

- **Job:** Show the batch-and-cache payoff to a builder with real data to turn into
  video, and tie it to templates they can reuse.
- **Serves / routes:** The Flutter dev. Routes to core-concepts and templates
  (docs.fluvie.dev/advanced/templates).
- **Copy:**
  - Headline: "Write one. Render a thousand."
  - Body: "One template plus a data list renders one video per row. The frame cache
    keys on content, so an unchanged frame is read, not redrawn. Change one number
    and only the frames that moved render again."
  - Pull quote: "A thousand data-driven videos, rendered like one."
- **Special treatment:** A "one template, one card per row" panel: a small data row
  (`rows = [ Q1, Q2, Q3, Q4 ]`) above a grid of cards, each tile labeled with its
  row and value, so the data-to-video mapping is literal.
- **Motion:** On scroll, the data row settles first, then the cards stamp in one per
  row, staggered. Hovering a card lifts it and shows its row value.
- **Accessibility:** The data row and the cards are real text, not images. Card
  labels carry their value as text, never color-coded only. Reduced motion: the
  cards appear in their final state at once.

### 5. From `fluvie init` to `fluvie render`

This is the getting-started the page must include. See the
[full content below](#getting-started-the-full-walkthrough).

- **Job:** Turn "looks cool" into "I just did it" without leaving the page. Strike
  at peak intent, right after the proof.
- **Serves / routes:** The Flutter dev. Routes to installation
  (docs.fluvie.dev/getting-started/installation) and your-first-video. Secondary:
  "Skip setup, scrub it live" to the demo.
- **Special treatment:** A vertical numbered "call sheet" with a perforation rail
  down one side. Each step is its own card with its own copy button. Step 3
  expands to the code, and the `hide Animation` line carries an inline note, as
  does the `Video build()` signature (it is the one contract the CLI looks for).
  The final card shows a small "change the data, render again" badge.
- **Motion:** Steps reveal with a gentle stagger. The perforation line threads
  downward as you progress. Each successful copy ticks that step's number (an
  allowed pop moment). The render command gets a tiny clapper-snap on copy. The
  payoff line fades in just after its command.
- **Accessibility:** A real ordered list, so a screen reader hears "step 2 of 5".
  Every command is selectable `code` with a labeled "Copy command" button, and
  success is announced in an `aria-live` region. The prereqs note is a real
  disclosure (`details` with `aria-expanded`). Reduced motion: no stagger and no
  line-draw, everything static.

### 6. The reel wall: twelve examples

This is the example gallery the page must include. See the
[gallery content below](#the-gallery-the-full-content).

- **Job:** Prove range and real output. Reward the visitor who just learned how to
  do it.
- **Serves / routes:** Everyone. Each tile routes to its live-demo lesson, with a
  secondary "view source" to the lesson file. Section CTA: "Scrub any of these
  live" to the demo.
- **Copy:**
  - Headline: "Twelve little films, each in one readable file."
  - Intro: "Every clip below is a real Fluvie render: text and motion, scenes and
    transitions, Ken Burns photos, charts that draw themselves, self-typing code, a
    beat-synced visualizer, captions, the lot. Hover to roll the clip, click to
    scrub it live."
- **Special treatment:** A film contact-sheet grid of twelve tiles, each a framed
  clip with a clapperboard caption strip (number and title). Be honest about
  assets: only three real clips exist today (01, 07, 12). Those autoplay on hover.
  The other nine show their poster frame with a "play in demo" affordance, no faked
  footage and no empty boxes. Dropping in the remaining clips later needs no layout
  change. Optional filter chips ("basics / data / media / audio / code /
  transitions").
- **Motion:** A single deliberate "cut" on entering the section, then tiles stagger
  in as a diagonal render-wave. Only one tile plays at a time (hover or focus
  starts it, leaving pauses it) to spare the GPU. Click does a quick lens zoom, then
  routes to the demo.
- **Accessibility:** Each tile is a real link with a descriptive name ("Lesson 07,
  A data story, opens the live demo"). The `video` is muted, `playsinline`, and
  decorative, with a poster fallback so focus never lands on a blank tile. Keyboard
  focus plays a tile the same way hover does. The grid uses a roving tabindex
  (arrows move, Enter opens). Caption strips sit on a solid scrim for contrast over
  any frame. Reduced motion: tiles stay on posters, no autoplay and no wave, and
  each tile has an explicit play control for anyone who wants the clip.

### 7. The crew: seven packages

This is the ecosystem overview the page must include. See the
[ecosystem content below](#the-ecosystem-the-full-content).

- **Job:** Show Fluvie is a small coordinated toolkit, route each visitor to the
  one package they need, while saying most people only need `fluvie`.
- **Serves / routes:** Dev and expert. Each card routes to its pub.dev page and its
  best doc path.
- **Special treatment:** A "shot list" or "studio departments" board, not a table.
  A playhead rail threads all seven rows. Each row carries a name, a role, a one-line
  description, and a destination chip, with a small distinct glyph per package for
  pattern-matching. The `fluvie` card carries permanent quiet emphasis as the lead,
  with a pinned "Start here".
- **Motion:** Rows stagger in top to bottom, like a call sheet being written. Hover
  or focus slides a playhead tick to the row, nudges the name a hair, and translates
  the destination chip's arrow. One row animates at a time. Siblings stay fully
  legible.
- **Accessibility:** A semantic list of links. Each card's accessible name includes
  the package name, its role, and its destination ("fluvie_cli, headless renderer
  CLI, opens pub.dev"). The crew metaphor is flavor, never the only label. The whole
  row is one click target and one focus stop. Links indicate they leave the site.
  Reduced motion: links are always visible, no reveal-on-hover dependence, no
  stagger.

### 8. Open source, on purpose

This is the open-source section the page must include. See the
[open-source content below](#open-source-the-full-content).

- **Job:** Make the open-source story the reason to adopt, not a footnote.
- **Serves / routes:** Everyone, the decision-sealer. Routes to the GitHub repo,
  the LICENSE, the contributing guide, and the self-host guide
  (rendering-on-a-server).
- **Special treatment:** A "show, do not claim" centerpiece: stat tiles (license,
  package count, lesson count, no per-render bill) in the style of certification
  marks. An honest GitHub stat strip (stars, latest release, license, open-issue
  count) so the section is never stale.
- **Motion:** A deliberate cut into the section. Pillar stamps press-and-settle on
  scroll, staggered. Hover lifts a tile and reveals its one-line elaboration. Repo
  stats count up once on first view.
- **Accessibility:** Pillars are a real list with full-text consequences, not
  hover-revealed. License and stats are text plus icon, never color-coded only.
  Live numbers degrade to a static accurate fallback if the fetch fails, no empty
  boxes. Reduced motion: stamps and count-up resolve at once.

### 9. Pick your seat: CLI / HTTP / MCP / live

- **Job:** Answer "how do I run this in my situation?" and fork the cold and the
  pro paths cleanly.
- **Serves / routes:** Everyone, self-sorting. Routes to the CLI (fluvie_cli docs),
  the server guide, the MCP guide, and the demo.
- **Copy:**
  - Headline: "Pick your seat."
  - Body: "Scrub it live in the browser. Render it from the CLI. Stand up your own
    render server. Or let an assistant shoot it for you. Same `Video`, four front
    doors. The engine is the same. Only the trigger changes."
- **Special treatment:** A door or lane switcher (a segmented control, or tall
  "stage doors"): Live / CLI / HTTP / MCP. Selecting one swaps a single panel to
  that door's idiomatic call (`fluvie render <key> --out file.mp4`, a `POST /render`
  snippet returning an MP4, an MCP tool call). An always-visible line: "The same
  video, whichever door you use." The "Try it live" lane is
  emphasized for cold visitors. The CLI lane carries the canonical render command.
- **Motion:** Only the selected or hovered door "opens" (a door-ajar lift or a light
  sweep) and its CTA slides into focus. Panel content cross-dissolves with reserved
  height, no layout jump.
- **Accessibility:** A real `role="tablist"` with arrow-key navigation and
  `aria-selected`. Panels are `tabpanel`s. Each snippet is real text with a copy
  button. The CTAs read distinctly in text, not by position. Reduced motion:
  instant panel swap, static doors. The "same frames" reassurance is always present
  as text.
- **Rendering modes by platform (the matrix):** Below the door switcher, a compact
  table answers "where does the encode run on my platform?" Three modes (Local
  FFmpeg, Server API, On-device) across four platforms (Desktop, Android, iOS,
  Web). Every supported cell links to its setup guide. The same `Video` feeds all
  three; only the encode edge changes.

  | Platform | Local (FFmpeg) | Server API | On-device |
  | --- | --- | --- | --- |
  | Desktop | yes, fluvie_cli (installation) | yes, fluvie_server client (rendering-on-a-server) | yes, local FFmpeg (the CLI) |
  | Android | — | yes, fluvie_server client (rendering-on-a-server) | yes, fluvie_mobile_encoder (on-device-mobile-rendering) |
  | iOS | — | yes, fluvie_server client (rendering-on-a-server) | yes, fluvie_mobile_encoder (on-device-mobile-rendering) |
  | Web | — | yes, fluvie_server client (rendering-on-a-server) | yes, fluvie_web_encoder, ffmpeg.wasm, opt-in (on-device-web-rendering) |

  A one-line note under the table covers combining platforms: one app on mobile and
  web can render on-device on both by picking the renderer per platform behind a
  conditional import, same `Video`. On the web you trade bundle size for the
  ffmpeg.wasm payload, so choose the Server API to keep the bundle light.

- **Audio support by platform:** A second line notes that declared audio
  (`Audio.music`/`Audio.sfx`) mixes on every renderer — looping beds, fades,
  trims, multi-track — with audio opt-in on-device and no local-file source on the
  web. Link to the canonical table at the audio guide
  (audio-and-captions, "Audio across platforms"). Do not re-tabulate it here.

### 10. Or just say what you want (AI + MCP)

- **Job:** Show the lowest-effort path. Describe a video in English, get a
  `VideoSpec` and an MP4. In the Playground the AI Assistant writes editable
  Flutter-style Dart you can read and refine, server-side, so the browser never
  holds a key. The "you do not even write the widgets, unless you want to" reveal.
- **Serves / routes:** Cold visitor and expert. Routes to the AI and MCP guide
  (docs.fluvie.dev/guides/ai-and-mcp), the Playground (demo.fluvie.dev), fluvie_ai,
  fluvie_server, and the hosted MCP at mcp.fluvie.dev.
- **Copy:**
  - Headline: "Or just say what you want."
  - Body: "'A 10-second product promo, brand teal, big counter to 10,000, confetti
    on the last beat.' `fluvie_ai` turns that into a real `VideoSpec`. In the
    Playground, the AI Assistant writes editable Flutter-style Dart into the editor,
    so you can read it and refine it with another sentence. The model runs on the
    server, so your browser never holds a key. The MCP server in `fluvie_server`
    lets your assistant do the same from a chat." Keep the honest framing: this is
    the optional easy mode, not the only mode.
- **Special treatment:** A "prompt then spec then film" triptych: a chat-style
  prompt bubble, the generated `VideoSpec` code, and the rendered clip, joined by
  the same left-to-right connector motif as the hero. A narrative callback that
  makes the page feel authored, not assembled.
- **Motion:** On scroll-in, the prompt "sends", the spec types itself in, then the
  film plays. One pass, then settle. The same cause-and-effect grammar as the hero.
- **Accessibility:** All three panels are real text and elements. The video has a
  caption and a poster. The typing is decorative over content that is already there.
  A screen reader reads prompt, then spec, then "rendered output", in order. Reduced
  motion: present the prompt, the spec, and the poster static, with a play
  affordance.

### 11. Roll camera: the final router

- **Job:** Last chance to route every persona to exactly the right next step.
- **Serves / routes:** Everyone, explicitly split. New visitors to the demo, devs
  to getting-started, experts to the docs and GitHub.
- **Copy:**
  - Headline: "Roll camera."
  - Body: "New here? Watch twelve examples render live. Building something? Five
    steps to your first MP4. Already shipping? Straight to the docs." Then the
    tagline once more.
- **Special treatment:** A three-up cinema "marquee" of clearly labeled
  destinations, each with one verb-led CTA and a half-line of who-it-is-for, plus
  two or three deep sub-links where they help (the docs card exposes installation,
  your-first-video, core-concepts, and the cheatsheet so an expert deep-links
  without opening the docs home). One primary action ("Render your first video") is
  visually dominant, the others quieter but clearly available.
- **Motion:** A soft "lights" shimmer on the dominant CTA only (subtle, not a
  casino). Hover lifts each card. A single confidence beat settles the tagline on
  scroll-in.
- **Accessibility:** Three real links with explicit text destinations. The dominant
  CTA is distinguished by text and weight, not color alone. Sub-links are each
  labeled and reachable. Focus order puts the primary first, with strong focus
  rings (this is the conversion point). Reduced motion: no shimmer and no lift,
  static cards.

### 12. Footer: end credits

- **Job:** Catch every remaining intent and state the honest facts, with no second
  pitch.
- **Serves / routes:** Expert and returning visitor. Routes everywhere, grouped as
  an index.
- **Copy:** Sign-off: "That is a wrap." with the tagline small underneath. Plus:
  "Made with Flutter, rendered with FFmpeg, MIT licensed."
- **Columns / routes:**
  - **Learn:** installation, your-first-video, core-concepts, cheatsheet.
  - **Guides:** ai-and-mcp, rendering-on-a-server.
  - **Packages:** all seven pub.dev links.
  - **Try:** demo.fluvie.dev, mcp.fluvie.dev.
  - **Project:** GitHub, Issues, Discussions, MIT license, Releases.
- **Special treatment:** A calm, scannable multi-column credits index (the one
  place a plain list is correct), capped by a small clapperboard "that is a wrap"
  mark and a "back to top" control.
- **Motion:** None by default. Only an underline-grow on link hover and focus. One
  optional "credits settle" on first reveal.
- **Accessibility:** A real `footer` with grouped `nav` landmarks and visible
  headings, full keyboard order, visible focus, strong contrast, and external links
  labeled as leaving the site. Fully usable with zero motion.

---

## Getting started, the full walkthrough

This is the content for section 5. Render it as the numbered call sheet. Each step
is one short line plus one copyable command or code block.

> Honesty note for the build: every step below is exactly right for a fresh
> project. There is no hidden setup left. A Fluvie project is a composition file,
> an `assets/` folder, and a pubspec; the CLI generates the capture harness and
> the preview app per invocation, so there is nothing to wire and nothing to
> commit. Link "Read the full guide" to installation anyway, for the reader who
> wants the why.

**Prereqs (a collapsible note at the top).** You need Flutter 3.44 or newer. That
is the list. You do not need FFmpeg: the first render downloads a pinned,
checksum-verified build and caches it.

```sh
flutter --version
```

**Step 1. Install the renderer.** The CLI that scaffolds, previews, and writes the
file.

```sh
dart pub global activate fluvie_cli
```

**Step 2. Scaffold the project.** A composition, an assets folder, a pubspec. No
app, no harness, no registry, no platform directories.

```sh
fluvie init --dir my_promo
cd my_promo && flutter pub get
```

**Step 3. Write the video.** One scene, a gradient, a title that fades in and pops.
Hide Flutter's own `Animation` so Fluvie's wins. The file exposes a top-level
`Video build()`: that is the one contract `preview` and `render` look for.

```dart
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

Video build() {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    scenes: [
      Scene(
        duration: 4.seconds,
        background: Background.gradient(const [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        children: [
          const Text(
            'Hello, Fluvie',
            style: TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
          ).animate([Animation.fadeIn(), Animation.pop()]),
        ],
      ),
    ],
  );
}
```

**Step 4. Watch it live.** Hot reload. Edit the file, save, watch it redraw. There
is no app to run.

```sh
fluvie preview ./lib/example_video.dart
```

**Step 5. Render it.** When it looks right, write the MP4. No display needed.

```sh
fluvie render ./lib/example_video.dart --out promo.mp4
```

**The payoff (final card).** Change the data, run the render, ship the file. Your
video is a build artifact now. That is the whole point.

CTAs under the call sheet: "Read the full guide" to installation, "Your first
video" to your-first-video, and a quiet "Skip setup, scrub it live" to the demo.

---

## The gallery, the full content

Twelve tiles, in order. Each tile: the number, the title, and a one-sentence "what
it teaches". Real clips exist for 01, 07, and 12 today. The rest show posters until
the clips are generated (see [gallery assets](#gallery-assets-format-and-source)).

| # | Title | What it teaches | Live demo route |
| --- | --- | --- | --- |
| 01 | Hello, video | The smallest complete video: one scene, a gradient, a title that fades and pops. | demo.fluvie.dev (lesson 01) |
| 02 | Text and motion | A plain Column, a staggered enter, `previous` trigger chains, and an ambient float. | lesson 02 |
| 03 | Timing and triggers | Anchored gradient shift, `Trigger.whenEnds` gating, and `.show` windows. No frame numbers. | lesson 03 |
| 04 | Scenes and transitions | Three scenes, a crossFade, a SharedElement morph, a camera push, and a wipe. | lesson 04 |
| 05 | Images and clips | A photo in a polaroid with Ken Burns, plus a trimmed video clip. No async pop-in. | lesson 05 |
| 06 | A photo collage | A data-driven photo wall staggering in, grain and vignette, a seeded confetti burst. | lesson 06 |
| 07 | A data story | A counter, a bar chart that grows, a line that draws on, a donut that sweeps. | lesson 07 |
| 08 | Code and terminal | A title card, a Code block that types itself out, a Terminal that streams output. | lesson 08 |
| 09 | Diagrams and web pages | A Mermaid reveal, a Markdown explainer, and inline HTML in a browser frame. | lesson 09 |
| 10 | Audio and captions | A music bed with beat detection, a bar visualizer pulsing on the bass, SRT subtitles. | lesson 10 |
| 11 | Templates and aspects | A built-in StatHighlight template, an Adaptive per-aspect layout, a FluvieTheme. | lesson 11 |
| 12 | The kitchen sink | Every idea in one reel: beat-synced pop, counter, captions, transitions, effects. | lesson 12 |

### Gallery assets, format and source

- Each tile uses a looping muted `video` as the primary preview, with a GIF
  fallback and a static poster. Markup pattern:

```html
<figure class="tile">
  <video class="tile-media" autoplay loop muted playsinline preload="none"
         poster="media/07_charts.poster.webp"
         aria-label="Lesson 07: A data story, charts draw themselves">
    <source src="media/07_charts.webm" type="video/webm">
    <source src="media/07_charts.mp4"  type="video/mp4">
    <img src="media/07_charts.gif" alt="Lesson 07: A data story, charts draw themselves">
  </video>
  <figcaption>
    <h3>07 . A data story</h3>
    <p>A counter, a bar chart that grows, a line that draws on, a donut that sweeps.</p>
    <a href="https://demo.fluvie.dev/#07_charts">Scrub it live</a>
  </figcaption>
</figure>
```

- The assets live in `web/site/public/media/<key>.{mp4,webm,poster.webp,gif}`. They
  are generated by `tool/web/regenerate_gallery.sh` (or `melos run web:gallery`). See
  `web/site/MAINTAINING.md` for how and when to regenerate.
- Only one tile plays at a time, and playback pauses off-screen and under reduced
  motion.

---

## The ecosystem, the full content

Section 7. Render as the shot-list board. `fluvie` leads with "Start here". Most
people only need `fluvie`. All eight are on pub.dev. All eight are MIT.

| Package | Role | One line | Best path |
| --- | --- | --- | --- |
| **fluvie** | the camera | Describe a video, render an MP4. This is the one that does the magic. | pub.dev/packages/fluvie, then your-first-video |
| **fluvie_cli** | the projectionist | `fluvie render <key> --out file.mp4`. Headless, scriptable, no editor in sight. | pub.dev/packages/fluvie_cli, then installation |
| **fluvie_lints** | continuity supervisor | Catches timing and layering mistakes before they catch you. | pub.dev/packages/fluvie_lints, then cheatsheet |
| **fluvie_ai** | the screenwriter | Turn a plain sentence into a VideoSpec. Claude, Gemini, Mistral, or Ollama. | pub.dev/packages/fluvie_ai, then ai-and-mcp |
| **fluvie_server** | the studio you host | Render API, MCP server, and a docs helper in one binary. Host the full AI stack yourself. | pub.dev/packages/fluvie_server, then rendering-on-a-server |
| **fluvie_mobile_encoder** | the on-device camera operator | Render to MP4 on the phone itself, no FFmpeg and nothing leaves the device. | pub.dev/packages/fluvie_mobile_encoder, then on-device-mobile-rendering |
| **fluvie_web_encoder** | the in-browser camera operator | Render to MP4 in the browser with ffmpeg.wasm, opt-in, nothing leaves the page. | pub.dev/packages/fluvie_web_encoder, then on-device-web-rendering |

---

## Open source, the full content

Section 8. Heading: "MIT. Inspect it, fork it, host it, keep it."

Lead: "No black box and no per-render bill. The renderer is open, so you can read
exactly how every frame is drawn, fork it, and host it yourself. Self-host the API,
vendor the code, or just read how the timing model actually works. It is free, and
it stays free."

Pillars (each a claim with its Fluvie-specific consequence, so it never reads as
boilerplate):

- **Inspectable.** The timing resolver is a few hundred readable lines. Read it
  before you trust it.
- **Auditable.** A frame hash is a receipt. Render twice, diff, trust.
- **No lock-in.** Plain Dart and FFmpeg. Eject any time. Your videos are just code.
- **Self-hostable.** Run the render API in your own Docker. Your media never leaves
  your network.
- **Free, and built in the open.** MIT, with a public roadmap and issues. The lints
  and the lessons came from real use.

Routes: "Read the source" to the GitHub repo, "Good first issues" to the
contributing guide, "Self-host the render API" to rendering-on-a-server.

---

## Global motion and accessibility

This applies page-wide. Define these once and have every section compose from them.

### Motion principles

- **Two speeds only.** A snappy "micro" speed for hover, focus, and press. A longer
  eased "scene" speed for reveals and section transitions. One shared token each.
- **One easing family.** Ease-out for entrances, its mirror ease-in for exits, and a
  single reserved "pop" overshoot used only where it echoes `Animation.pop()` (copy
  confirmations, the primary CTA). Do not spend the pop on everything.
- **Stagger is the house style.** Any list, grid, or row enters with a consistent
  per-item delay, the same offset and gap everywhere, so cards, rows, tiles, and
  steps share one rhythm.
- **Forward progress reads along a playhead,** top to bottom. Occasional
  frame-quantized motion (the hero fill, the render pours) winks at "frame by
  frame", used sparingly.
- Tokens to define once: micro-speed, scene-speed, ease-out and ease-in, the
  reserved pop, the stagger gap, the reveal translate distance, the focus-ring spec,
  and the global reduced-motion switch.

### Named scroll patterns (reuse these)

- **A. Keyframe Reveal.** The default entrance. Elements appear in a short staggered
  sequence, heading first, interactive payload last. Fires once at a threshold. Does
  not re-fire on scroll-up. Reduced motion: fade in together or appear at once.
- **B. Sticky Clapperboard.** A section pins while content advances through two to
  four "takes". A steady visual on one side, a swapping caption on the other,
  progress shown as numbered ticks. Use for the one-idea morph and the
  getting-started. Reduced motion: unpin, render the takes as a normal stack.
- **C. Scroll-Scrubbed Render.** Scroll position is the playhead: code "executes"
  while frames fill in lockstep. Quantize to a fixed number of frames. Use at most
  twice, the hero and one proof. Reduced motion: a single short autoplay clip or a
  static before-and-after with a real Play.
- **D. Continuity Carry.** A motif (a film cell, the playhead line) translates across
  a section boundary instead of disappearing. Echoes SharedElement. Use on two or
  three seams. Reduced motion: the element exists in both, no morph.
- **E. Playhead Parallax.** One thin back layer (a faint frame-grid or sprocket
  column) moves at a slightly different rate. Strictly one layer, small offset, never
  under text. Reduced motion: static.
- **F. Cut Transition.** A deliberate fast cut between two sections (a wipe, an iris,
  a single clapper flash). Use on one or two high-drama seams only. Reduced motion:
  instant change or a soft cross-fade.

### Making lists, tables, and grids special without hurting scannability

- **Scannability is sacred.** Alignment, a consistent rhythm, and one clear reading
  order come first. Motion layers on top and never reflows content after it settles.
- **Stagger, do not scatter.** Entrances follow reading order so the eye is led.
- **Hover affects one item.** Only the hovered or focused item changes. Siblings
  stay fully legible. Never dim the rest.
- **Steady state is calm.** All personality lives in entrance and hover. At rest,
  these are quiet and readable. This is the rule that protects scannability.
- Turn the package "table" into a shot list, the feature cards into a contact sheet,
  the gallery into a contact sheet that comes alive, and the getting-started into a
  numbered timeline with a playhead. Keep the semantics standard underneath.

### Accessibility gate

- **Reduced motion.** A global `prefers-reduced-motion: reduce` switch maps every
  pattern to its fallback: no parallax, no pin or scroll-hijack, no autoplay, no
  draw-on sweeps, no overshoot. Replace transforms with instant changes or short
  cross-fades. Informational motion stays without easing: the scroll-progress
  playhead, the hero scrubber (user-driven), and copy and render confirmations. Gate
  scroll-driven and canvas animations with a JS `matchMedia` check, since CSS alone
  will not stop a scroll-scrub.
- **Keyboard.** Skip-to-content first in tab order. The hero scrubber and the
  timeline lever are real sliders (arrows step, Home, End, PageUp, PageDown). The
  gallery is a roving-tabindex grid (arrows move, Enter opens) with hover and focus
  parity. The "pick your seat" doors are a tablist. Pinned or scrubbed sections never
  trap keyboard scroll and always offer a non-scroll control (a Play button) to reach
  the end state. The mobile menu traps focus while open, closes on Escape, and
  restores focus on close.
- **Focus.** Every interactive element has a clearly visible `:focus-visible`
  indicator with a non-color component (outline thickness or offset, plus optional
  scale or weight), at least as strong as its hover state. Focus order follows
  reading order. No focus traps except intentional, escapable ones.
- **ARIA and semantics.** Scrubber: `role="slider"` with `aria-valuemin`,
  `aria-valuemax`, `aria-valuenow`, `aria-valuetext`. Render, play, and copy status
  via `aria-live="polite"`. Sticky-narration takes expose the active step with
  `aria-current` and read as plain stacked content when unpinned. Gallery tiles,
  package rows, and router cards are real links or buttons whose accessible name
  includes the destination. Custom toggles and doors use `aria-expanded`,
  `aria-selected`, and `aria-controls`, with Escape to close. Decorative motifs
  (sprockets, playhead rails, grain, connectors) are `aria-hidden`.
- **Contrast and non-color cues.** All text and meaningful UI meets a strong contrast
  ratio against its surface in every state, and hover or focus never drops contrast
  below the threshold. Meaning is never encoded in color alone: code-line highlights,
  active nav, selected filter, destination chips, and "identical vs broken" each carry
  a second cue (weight, underline, marker, icon, position, the playhead tick). Text
  never sits directly on a moving, parallax, or grain layer. Keep it on its own steady
  surface, with caption strips on a solid scrim. No flashing faster than about three
  per second. Animate compositor-friendly transform and opacity, throttle scroll work,
  and defer heavy clips behind the poster until interaction (respect
  `prefers-reduced-data`).

---

## Persona journeys

Trace each persona down the page to confirm each one gets what they need and a clear
next click.

- **Cold visitor.** The hero (1) teaches in seconds with the code-and-film split and
  the three plain labels. The one idea (2) says it is not a screen recorder. They can
  skim the two dev-proof sections (3, 4) without getting lost. The gallery (6) wows
  them with real output. "Or just say what you want" (10) shows the no-widgets path.
  The final router (11) sends them to the live demo. Next click: demo.fluvie.dev.
- **Flutter dev.** The hero (1) shows real widget code and the `hide Animation` wink.
  The clever bit (3) lands the "oh, that is nice" with the move-the-title cascade. The
  payoff (4) sells batch-and-cache ("write one, render a thousand"). At peak
  intent, getting-started (5) is a copy-paste path to a rendered MP4. The crew (7)
  shows how it scales, open source (8) seals
  trust, and "pick your seat" (9) shows it fits their pipeline. Next click: Get
  started or installation, or they copy the commands in-page.
- **Existing user.** The sticky nav (0) lets them jump out at once to Docs, Demo,
  Packages, or GitHub at any depth. If they scroll, the crew grid (7) deep-links each
  package, "pick your seat" (9) and the AI section (10) route to CLI, HTTP, MCP, and
  the hosted MCP, and the footer (12) is a full index with docs deep-links. Next
  click: the exact deep-link they came for.

---

## Open decisions for the owner

These are choices to make in design, with a recommended default.

1. **Hero fidelity.** The full scroll-scrubbed hero (filmstrip, scrubber, render
   pour) is the showpiece and the most expensive to build and keep accessible.
   Recommended: ship the filmstrip-only version first (it fills on Play), upgrade to
   the scrubber later.
2. **Ecosystem visual.** Default is the calm shot-list cards. An orbital dependency
   diagram (core in the center, others orbiting, connectors drawing on) adds drama but
   costs scannability and accessibility. Recommended: keep the shot list. If you add
   the orbit, keep the plain list underneath as the source of truth.
3. **Gallery placeholders.** Only 01, 07, and 12 have real clips today. Decide whether
   the other nine show a poster with "play in demo", or whether to render the
   remaining nine before launch. The `web:gallery` pipeline is ready and only needs
   the `build/<key>.mp4` renders. Recommended: posters now, full set soon.
4. **Live GitHub stats.** The nav and the open-source section want live star, release,
   and issue counts. Decide whether to wire the GitHub API (with a static fallback) at
   launch or ship static numbers. Either way a failed fetch must degrade gracefully.
5. **Persona quick-routes in the nav.** Optional "New here / Flutter dev / I already
   use Fluvie" affordance near the top. Faster routing, but more nav chrome. Recommended:
   rely on the hero and the final router unless analytics say otherwise.
6. **AI section placement.** It currently sits after the render forks. If the
   no-widgets reveal should hit the cold visitor earlier, move it up near the gallery.
7. **Tagline consistency.** Keep "You write widgets. Fluvie shoots the film." as the
   one-liner. Allow the longer "Made with Flutter, rendered with FFmpeg, MIT licensed."
   only in the footer.

## Where to next

- The maintenance guide: [`web/site/MAINTAINING.md`](MAINTAINING.md).
- The gallery pipeline: `tool/web/regenerate_gallery.sh` and `melos run web:gallery`.
- The sync skill: `.claude/skills/sync-website/SKILL.md`.
