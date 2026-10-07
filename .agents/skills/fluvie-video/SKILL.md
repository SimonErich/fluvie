---
name: fluvie-video
description: Create or revise a Fluvie video in a new or existing Flutter project, from a prompt and local assets through preview, render, and delivery review.
---

# Create a Fluvie video

Use this skill when the user asks to make or edit a video with Fluvie. Produce
editable Dart composition code and a rendered video when the project and tools
allow it. Do not require MCP; use the installed Fluvie CLI and the user's normal
project tools.

## Choose the workflow

- **Quick** is the default. If the user gives a topic and scenes, treat those as
  direction and build the video. Ask only for a decision that blocks a sound
  result; otherwise make a reasonable, visible choice and report it.
- **Guided** is for requests to work in stages, get approvals, or build a
  storyboard. Get approval at the checkpoints below before spending time on the
  next stage. Keep feedback actionable and allow the user to revise any stage.

## Ground the project

1. Read `fluvie docs --context` when the CLI is installed. Otherwise open the
   [Fluvie AI entry page](https://fluvie.dev/for-ai) and follow only the linked
   docs needed for this task.
2. Inspect the workspace before scaffolding. For an existing Flutter project,
   preserve its structure and use `fluvie init` to add Fluvie if needed. For a
   new project, use the documented project setup. Do not replace unrelated app
   code.
3. Read relevant story notes and inspect real media before assigning scenes,
   trims, or captions. Use `fluvie assets <directory> --json` for file facts.
   A filename is not evidence of what an image or clip contains. Keep original
   asset paths in the composition.
4. Confirm or infer duration, aspect ratio, tone, narration/music, and output
   location from the request and project. State assumptions briefly. Check
   current factual claims against reliable sources when the video depends on
   facts that can change.

## Guided checkpoints

1. **Story:** present a numbered beat list with approximate timing, on-screen
   text or narration, and the purpose of each beat. Ask for approval or edits.
2. **Look:** show two to four distinct style frames, with references alongside
   them when provided. Use available image tools or renderable still concepts;
   do not claim a frame was rendered when it was only described. Ask which look
   to use.
3. **Storyboard:** show each beat as a numbered panel with its visual, text,
   duration, sound, and transition into the next panel. Ask for approval or
   panel-specific changes.
4. **Build and delivery:** create the approved composition, preview and render
   it, then show the video and review findings. Apply requested revisions and
   review again.

Do not force these checkpoints into Quick mode. If an approval is pending,
wait before doing work that depends on it.

## Build and review

- Prefer a top-level `Video build()` in a readable Dart file, using the public
  `package:fluvie/fluvie.dart` API. Preserve existing conventions and custom
  widgets in an established project.
- Use the user's scene direction. Keep timing, text, and transitions coherent;
  avoid adding unsupported facts, unrequested assets, or decorative complexity
  that makes the story harder to read.
- Run `fluvie validate <file> --json`, then `fluvie preview <file>` and
  `fluvie render <file> --machine`. Resolve actionable validation or render
  errors before delivery. Use `fluvie review <file> --render --strict-decode
  --json` when a complete render review is available.
- Inspect the actual output when possible. Report the Dart file, video path,
  format and duration, checks performed, and any limitation that prevented a
  preview, render, or review. Never describe an unrendered composition as a
  finished video.

## References

- Start or add a project and work with assets: [authoring with assets](https://docs.fluvie.dev/getting-started/authoring-with-assets/)
- CLI, provider generation, MCP, and offline docs: [AI and MCP](https://docs.fluvie.dev/guides/ai-and-mcp/)
- Story and visual evidence from local media: [asset evidence](https://docs.fluvie.dev/guides/asset-evidence/)
- Review rendered output: [reviewing a video](https://docs.fluvie.dev/guides/reviewing-a-video/)
- API example lookup: [cheatsheet](https://docs.fluvie.dev/reference/cheatsheet/)
