import 'dart:async';
import 'dart:convert';

import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/api/config/duration_parsing.dart';
import 'package:fluvie_server/src/api/http/job_response.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/api/jobs/job_status.dart';
import 'package:fluvie_server/src/api/jobs/render_job.dart';
import 'package:fluvie_server/src/api/render/render_request.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';

/// A [RenderGateway] that renders in the same process as the API.
///
/// It shares the server's [ServerDependencies] — the same render queue, job
/// store, file store, and signer the HTTP handlers use — so MCP build mode needs
/// no loopback socket and no second auth token. It mirrors the client's
/// submit-then-poll loop and throws an [ApiClientException] on failure or timeout
/// so MCP behaves the same whether it renders locally or against a remote API.
final class LocalRenderGateway implements RenderGateway {
  /// Creates a gateway over the shared [ServerDependencies]. `pollInterval` and
  /// `wait` are injectable so tests drive the poll loop without real delays.
  LocalRenderGateway(
    this._deps, {
    Duration? pollInterval,
    Duration? timeout,
    Future<void> Function(Duration)? wait,
  }) : _pollInterval = pollInterval ?? const Duration(milliseconds: 100),
       _timeout = timeout ?? const Duration(minutes: 10),
       _wait = wait ?? _realWait;

  final ServerDependencies _deps;
  final Duration _pollInterval;
  final Duration _timeout;
  final Future<void> Function(Duration) _wait;

  @override
  Future<RenderJobView> render(ApiRenderRequest request) async {
    final body = request.toJson();
    final renderRequest = RenderRequest.fromJson(body);
    final created = await _deps.queue.enqueue(
      renderRequest,
      visibility: _visibility(body),
      ttl: _ttl(body),
    );

    var job = created;
    var waited = Duration.zero;
    while (_isPending(job)) {
      if (waited >= _timeout) {
        throw const ApiClientException('Timed out waiting for the render to finish');
      }
      await _wait(_pollInterval);
      waited += _pollInterval;
      job = await _deps.jobStore.get(created.id) ?? job;
    }
    if (job.status == JobStatus.failed) {
      throw ApiClientException(job.error ?? 'Render failed');
    }
    return buildJobView(
      job,
      config: _deps.config,
      signer: _deps.signer,
      fileStore: _deps.fileStore,
    );
  }

  @override
  Future<ApiValidationResult> validate(String code) async =>
      ApiValidationResult.fromJson((await _deps.codeValidator.validate(code)).toJson());

  @override
  Future<Map<String, Object?>> fetchSpecSchema() async {
    final decoded = jsonDecode(_deps.schemaJson);
    if (decoded is! Map) {
      throw const ApiClientException('The VideoSpec schema is not a JSON object');
    }
    return decoded.cast<String, Object?>();
  }

  @override
  void close() {}

  bool _isPending(RenderJob job) =>
      job.status == JobStatus.queued || job.status == JobStatus.running;

  StoreVisibility _visibility(Map<String, Object?> body) {
    final value = body['visibility'];
    if (value == null) {
      return _deps.config.publicByDefault ? StoreVisibility.public : StoreVisibility.private;
    }
    if (value == 'public') return StoreVisibility.public;
    if (value == 'private') return StoreVisibility.private;
    throw const ApiClientException('visibility must be "public" or "private"');
  }

  Duration? _ttl(Map<String, Object?> body) {
    final value = body['ttl'];
    if (value == null) return null;
    // ApiRenderRequest always emits ttl as a string.
    try {
      return parseHumanDuration(value as String, label: 'ttl');
    } on FormatException catch (error) {
      throw ApiClientException(error.message);
    }
  }

  // coverage:ignore-start: real delay; tests inject an instant wait.
  static Future<void> _realWait(Duration duration) => Future<void>.delayed(duration);
  // coverage:ignore-end
}
