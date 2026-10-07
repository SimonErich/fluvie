# Build a Fluvie video with an AI assistant

Give a coding assistant a topic, the scenes you want, and a link to Fluvie's AI
entry page. The assistant can use the Fluvie CLI and your project files directly;
MCP is optional.

```text
Create a video using Fluvie: https://fluvie.dev/for-ai
Topic: [what the video is about]
Scenes: [the scenes, in order]
Use the quick path. Use assets in ./assets, write the composition to
lib/my_video.dart, preview it, and render the MP4.
```

Use **quick** for direct creation. The assistant follows your scene direction,
inspects available assets, makes reasonable choices for missing details, and
builds and reviews the video. It asks only when an answer would materially change
the result and cannot be inferred.

Use **guided** when you want to approve the creative direction before rendering.
The assistant checks the story beats, then the visual look, then a numbered
storyboard with sound and transitions. You can approve or revise each checkpoint
before it moves on to the next stage.

The reusable [Fluvie video skill](https://fluvie.dev/skills/fluvie-video/SKILL.md)
contains the agent workflow. In an installed Fluvie project, start with
`fluvie docs --context` for version-matched offline guidance. The [AI and MCP
guide](ai-and-mcp.md) explains the CLI, local models, and optional MCP tools.

## What the assistant should deliver

- Readable Dart composition code that remains editable.
- A preview and rendered video when the local project and required tools allow it.
- A concise report of the output paths and checks performed.

For real projects, ask the assistant to read story notes and inspect the actual
media before choosing scene order or timing. The `fluvie assets` command reports
file facts; it does not determine what an image or video depicts.
