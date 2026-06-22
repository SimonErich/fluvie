import 'dart:convert';

import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/mcp/mcp_tool.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';

/// Builds the Fluvie MCP tool set, each wired to [gateway].
///
/// The tools cover the whole authoring loop: generate from a prompt, refine an
/// existing spec, render a spec or a registered composition, and fetch the spec
/// schema the model authors against.
List<McpTool> buildFluvieTools(RenderGateway gateway) => [
  McpTool(
    name: 'generate_video',
    description:
        'Author a Fluvie video from a natural-language prompt and render it. '
        'Returns a download URL.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'prompt': {'type': 'string', 'description': 'What the video should show.'},
        'aspect': {'type': 'string', 'description': 'Optional aspect, e.g. "16:9", "9:16", "1:1".'},
        'format': {
          'type': 'string',
          'description': 'Optional: mp4, gif, imageSequence, transparent.',
        },
        'provider': {'type': 'string', 'description': 'Optional LLM provider override.'},
      },
      'required': ['prompt'],
    },
    handler: (args) async => _describe(
      await gateway.render(
        ApiRenderRequest.prompt(
          _requireString(args, 'prompt'),
          provider: _optString(args, 'provider'),
          aspect: _optString(args, 'aspect'),
          format: _optString(args, 'format'),
        ),
      ),
    ),
  ),
  McpTool(
    name: 'edit_video',
    description:
        'Refine an existing Fluvie VideoSpec with a natural-language change, '
        'then render it. Returns a download URL.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'base': {'type': 'object', 'description': 'The current VideoSpec to change.'},
        'change': {'type': 'string', 'description': 'The change to make.'},
        'aspect': {'type': 'string', 'description': 'Optional aspect override.'},
        'provider': {'type': 'string', 'description': 'Optional LLM provider override.'},
      },
      'required': ['base', 'change'],
    },
    handler: (args) async => _describe(
      await gateway.render(
        ApiRenderRequest.edit(
          base: _requireMap(args, 'base'),
          change: _requireString(args, 'change'),
          provider: _optString(args, 'provider'),
          aspect: _optString(args, 'aspect'),
        ),
      ),
    ),
  ),
  McpTool(
    name: 'render_video',
    description: 'Render a Fluvie VideoSpec (JSON) to a video. Returns a download URL.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'spec': {'type': 'object', 'description': 'A serialized Fluvie VideoSpec.'},
        'aspect': {'type': 'string', 'description': 'Optional aspect override.'},
        'format': {
          'type': 'string',
          'description': 'Optional: mp4, gif, imageSequence, transparent.',
        },
      },
      'required': ['spec'],
    },
    handler: (args) async => _describe(
      await gateway.render(
        ApiRenderRequest.spec(
          _requireMap(args, 'spec'),
          aspect: _optString(args, 'aspect'),
          format: _optString(args, 'format'),
        ),
      ),
    ),
  ),
  McpTool(
    name: 'render_composition',
    description:
        'Render a composition registered in the render project by its key '
        '(for example "demo" or a lesson key). Returns a download URL.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'key': {'type': 'string', 'description': 'The registered composition key.'},
        'aspect': {'type': 'string', 'description': 'Optional aspect override.'},
        'format': {
          'type': 'string',
          'description': 'Optional: mp4, gif, imageSequence, transparent.',
        },
      },
      'required': ['key'],
    },
    handler: (args) async => _describe(
      await gateway.render(
        ApiRenderRequest.key(
          _requireString(args, 'key'),
          aspect: _optString(args, 'aspect'),
          format: _optString(args, 'format'),
        ),
      ),
    ),
  ),
  McpTool(
    name: 'get_video_spec_schema',
    description: 'Fetch the Fluvie VideoSpec JSON Schema so you can author valid specs.',
    inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
    handler: (_) async => McpToolResult.text(
      const JsonEncoder.withIndent('  ').convert(await gateway.fetchSpecSchema()),
    ),
  ),
];

McpToolResult _describe(RenderJobView job) {
  final lines = <String>[];
  final video = job.video?.downloadUrl;
  final poster = job.poster?.downloadUrl;
  if (video != null) lines.add('Video: $video');
  if (poster != null) lines.add('Poster: $poster');
  if (lines.isEmpty) lines.add('Render finished, but no downloadable file was returned.');
  return McpToolResult.text(lines.join('\n'));
}

String _requireString(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! String || value.isEmpty) {
    throw ArgumentError('Missing required "$key" (expected a non-empty string).');
  }
  return value;
}

Map<String, Object?> _requireMap(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is! Map) {
    throw ArgumentError('Missing required "$key" (expected an object).');
  }
  return value.cast<String, Object?>();
}

String? _optString(Map<String, Object?> args, String key) {
  final value = args[key];
  return value is String && value.isNotEmpty ? value : null;
}
