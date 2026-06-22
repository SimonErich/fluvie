import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/mcp/mcp.dart';

/// A [RenderGateway] test double that records the last request and replays a
/// canned job, schema, or failure with no network.
final class FakeRenderGateway implements RenderGateway {
  /// Creates a fake. [job] is returned by [render]; [schema] by
  /// [fetchSpecSchema]; set [failure] to make [render] throw it.
  FakeRenderGateway({
    this.job = const RenderJobView(id: 'job', status: 'succeeded'),
    this.schema = const {'type': 'object'},
    this.failure,
  });

  /// The request passed to the most recent [render] call.
  ApiRenderRequest? lastRequest;

  /// The job [render] returns.
  RenderJobView job;

  /// The schema [fetchSpecSchema] returns.
  Map<String, Object?> schema;

  /// When set, [render] throws this instead of returning [job].
  Exception? failure;

  /// Whether [close] has been called.
  bool closed = false;

  @override
  Future<RenderJobView> render(ApiRenderRequest request) async {
    lastRequest = request;
    final error = failure;
    if (error != null) throw error;
    return job;
  }

  @override
  Future<Map<String, Object?>> fetchSpecSchema() async => schema;

  @override
  void close() => closed = true;
}
