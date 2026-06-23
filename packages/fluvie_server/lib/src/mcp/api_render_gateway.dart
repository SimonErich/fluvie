import 'dart:convert';

import 'package:fluvie_server/client.dart';
import 'package:fluvie_server/src/mcp/render_gateway.dart';
import 'package:http/http.dart' as http;

/// A [RenderGateway] backed by a running Fluvie render API.
///
/// Authoring (prompt/edit) and rendering both happen on the server, so this
/// gateway needs neither Flutter nor FFmpeg. The HTTP client is injectable so
/// tests drive it with a mock and no socket.
final class ApiRenderGateway implements RenderGateway {
  /// Creates a gateway against [baseUrl], authenticating with [apiToken] when
  /// set. Renders give up after the timeout.
  ApiRenderGateway({
    required Uri baseUrl,
    String? apiToken,
    http.Client? httpClient,
    this._timeout = const Duration(minutes: 10),
  }) : _baseUrl = baseUrl,
       _apiToken = apiToken,
       _http = httpClient ?? http.Client() {
    _client = ApiRenderClient(baseUrl: baseUrl, apiToken: apiToken, httpClient: _http);
  }

  final Uri _baseUrl;
  final String? _apiToken;
  final Duration _timeout;
  final http.Client _http;
  late final ApiRenderClient _client;

  @override
  Future<RenderJobView> render(ApiRenderRequest request) =>
      _client.renderAndWait(request, timeout: _timeout);

  @override
  Future<ApiValidationResult> validate(String code) => _client.validate(code);

  @override
  Future<Map<String, Object?>> fetchSpecSchema() async {
    final response = await _http.get(
      _baseUrl.resolve('v1/schema/video-spec'),
      headers: {if (_apiToken != null) 'authorization': 'Bearer $_apiToken'},
    );
    if (response.statusCode != 200) {
      throw StateError('Schema request failed (HTTP ${response.statusCode})');
    }
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  @override
  void close() => _http.close();
}
