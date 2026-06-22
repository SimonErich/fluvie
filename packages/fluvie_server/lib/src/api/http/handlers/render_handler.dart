import 'dart:convert';

import 'package:fluvie_server/src/api/config/duration_parsing.dart';
import 'package:fluvie_server/src/api/config/server_config.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/job_response.dart';
import 'package:fluvie_server/src/api/http/json_body.dart';
import 'package:fluvie_server/src/api/jobs/render_queue.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/storage/file_store.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:shelf/shelf.dart';

/// Handles `POST /v1/renders`: validate the body, enqueue a render, and return
/// the queued job as `202 Accepted`.
final class RenderHandler {
  /// Creates the handler.
  const RenderHandler({
    required this.queue,
    required this.config,
    required this.signer,
    required this.fileStore,
  });

  /// The queue renders are submitted to.
  final RenderQueue queue;

  /// The server configuration (visibility defaults, AI env, base URL).
  final ServerConfig config;

  /// Signs private download URLs for the response.
  final DownloadTokenSigner signer;

  /// Used to attach file metadata to the response (none, for a queued job).
  final FileStore fileStore;

  /// Creates a render job from the request body.
  Future<Response> create(Request request) async {
    final body = await readJsonObject(request);
    final RenderRequest renderRequest;
    try {
      renderRequest = RenderRequest.fromJson(body);
    } on RenderRequestException catch (error) {
      throw ApiError.badRequest(error.message);
    }
    _ensureAiConfigured(renderRequest);
    final job = await queue.enqueue(
      renderRequest,
      visibility: _visibility(body),
      ttl: _ttl(body),
    );
    final view = await buildJobView(job, config: config, signer: signer, fileStore: fileStore);
    return Response(
      202,
      body: jsonEncode(view.toJson()),
      headers: {'content-type': 'application/json', 'location': '/v1/renders/${job.id}'},
    );
  }

  StoreVisibility _visibility(Map<String, Object?> body) {
    final value = body['visibility'];
    if (value == null) {
      return config.publicByDefault ? StoreVisibility.public : StoreVisibility.private;
    }
    if (value == 'public') return StoreVisibility.public;
    if (value == 'private') return StoreVisibility.private;
    throw const ApiError.badRequest('visibility must be "public" or "private"');
  }

  Duration? _ttl(Map<String, Object?> body) {
    final value = body['ttl'];
    if (value == null) return null;
    if (value is! String) throw const ApiError.badRequest('ttl must be a duration string');
    try {
      return parseHumanDuration(value, label: 'ttl');
    } on FormatException catch (error) {
      throw ApiError.badRequest(error.message);
    }
  }

  void _ensureAiConfigured(RenderRequest request) {
    final String? provider;
    if (request is PromptRenderRequest) {
      provider = request.provider;
    } else if (request is EditRenderRequest) {
      provider = request.provider;
    } else {
      return; // key/spec renders need no AI.
    }
    final selected = provider ?? config.aiEnv['FLUVIE_AI_PROVIDER'] ?? 'claude';
    if (selected == 'ollama') return; // local provider, no key needed.
    final keyVar = switch (selected) {
      'gemini' => 'GEMINI_API_KEY',
      'mistral' => 'MISTRAL_API_KEY',
      _ => 'ANTHROPIC_API_KEY',
    };
    if (!config.aiEnv.containsKey(keyVar)) {
      throw const ApiError.unavailable('AI rendering is not configured on this server');
    }
  }
}
