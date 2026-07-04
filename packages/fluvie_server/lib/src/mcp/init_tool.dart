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
      'pubspec dependencies, the `fluvie init` command, and the run/render/test '
      'steps.',
  inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
  handler: (_) async => McpToolResult.text(_guide),
);

const String _guide = '''
# Start a Fluvie project (Flutter-style, real code)

Fluvie compositions are real Flutter widget code: a `Video` of `Scene`s with the
widgets you already know. Use this when you want code in the repo, not a JSON
VideoSpec.

## Fastest path: the CLI

`fluvie init` scaffolds everything. Inside an existing Flutter project it drops a
starter composition and wires a render harness; outside one it creates a minimal,
runnable project with `flutter create`.

    dart pub global activate fluvie_cli
    fluvie init            # prompts for a location/name; Enter accepts the default
    # non-interactive: fluvie init --yes  (or --name <n> / --dir <project> / --yes)

Then:

    flutter pub get
    flutter run                              # live preview (scrub with the slider)
    fluvie render starter --out starter.mp4  # render an MP4

## Doing it by hand

Add the dependency:

    # pubspec.yaml
    dependencies:
      fluvie: ^0.1.0

Write the composition (lib/videos/starter.dart):

    import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
    import 'package:fluvie/fluvie.dart';

    Video starterVideo() {
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

## Check the format before rendering

Validate a `Video build()` snippet with the `validate_code` tool (static analysis
only; it never runs the code), then render the spec or composition. See the
"Start a Fluvie project" and "AI and MCP" documentation pages with `get_doc` for
the full walkthrough.
''';
