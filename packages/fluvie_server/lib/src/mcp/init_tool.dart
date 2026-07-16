import 'package:fluvie_server/src/mcp/mcp_tool.dart';

/// Builds the `init_project` tool: the on-ramp for Flutter-style (real Dart
/// widget code) Fluvie work.
///
/// It needs no render backend, so it is available in every MCP mode. The
/// description is tagged for "Flutter style", "real code", and "start a project"
/// so an assistant reaches for it instead of the JSON `generate_video` path when
/// the user wants real code.
McpTool buildInitProjectTool() => McpTool(
  name: 'init_project',
  description:
      'Start a new Fluvie project or add a Fluvie composition written in real '
      'Flutter/Dart widget code (not a JSON VideoSpec). Use this when the user '
      'asks for "Flutter style", "real code", "Dart code", or to set up, '
      'bootstrap, or start a Fluvie project. Returns the starter composition, the '
      'pubspec dependencies, the `fluvie init` command, and the preview/render '
      'steps.',
  inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
  handler: (_) async => McpToolResult.text(_guide),
);

const String _guide = '''
# Start a Fluvie project (Flutter-style, real code)

Fluvie compositions are real Flutter widget code: a `Video` of `Scene`s with the
widgets you already know. Use this when you want code in the repo, not a JSON
VideoSpec.

A project is a composition file, an `assets/` folder, and a `pubspec.yaml`.
There is no app to maintain and no capture harness: the CLI generates whatever a
render or a preview needs, every time you run one.

## Fastest path: the CLI

    dart pub global activate fluvie_cli
    fluvie init --name my_video   # scaffolds the project in the current directory
    flutter pub get

Then, pointing at the composition file itself:

    fluvie preview ./lib/my_video.dart              # live preview, hot reloads on save
    fluvie render ./lib/my_video.dart --out out.mp4 # render an MP4

## Doing it by hand

Add the dependency:

    # pubspec.yaml
    dependencies:
      fluvie: ^0.3.0

Write the composition (lib/my_video.dart). The entry point is a top-level
`Video build()`; pass `--entry <name>` to use a different name.

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

Keep the composition under `lib/`. A preview runs from a generated app outside
your project, and it can only import your composition through its package URI,
which only a file under `lib/` has.

Put media in `assets/`. The CLI derives the pubspec's `assets:` block from what
is there on every render, so a new subfolder never needs a pubspec edit.

## Check the format before rendering

Validate a `Video build()` snippet with the `validate_code` tool (static analysis
only; it never runs the code), then render the spec or composition. See the
"Start a Fluvie project" and "AI and MCP" documentation pages with `get_doc` for
the full walkthrough.
''';
