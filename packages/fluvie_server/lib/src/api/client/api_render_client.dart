import 'dart:async';
import 'dart:convert';

import 'package:fluvie_server/src/api/client/api_client_exception.dart';
import 'package:fluvie_server/src/api/client/api_render_job.dart';
import 'package:fluvie_server/src/api/client/api_render_request.dart';
import 'package:fluvie_server/src/api/client/api_validation_result.dart';
import 'package:http/http.dart' as http;

/// A web-safe HTTP client for the Fluvie render API.
///
/// Works on web, mobile, and desktop (it depends only on `package:http`). The
/// underlying [http.Client] is injectable so tests drive it with a mock and no
/// socket. Declared an `interface class` so consumers can mock it. Call [close]
/// when done.
interface class ApiRenderClient {
  /// Creates a client against [baseUrl] (e.g. `https://render.example.com`),
  /// authenticating with [apiToken] when set.
  ApiRenderClient({required this.baseUrl, this.apiToken, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// The API base URL.
  final Uri baseUrl;

  /// The bearer token sent on create/status requests, or `null` for none.
  final String? apiToken;

  final http.Client _http;

  /// Creates a render job, returning its queued [RenderJobView].
  Future<RenderJobView> createRender(ApiRenderRequest request) async {
    final response = await _http.post(
      baseUrl.resolve('v1/renders'),
      headers: {'content-type': 'application/json', ..._auth},
      body: jsonEncode(request.toJson()),
    );
    return _parse(response, expect: 202);
  }

  /// Fetches the current status of job [id].
  Future<RenderJobView> getJob(String id) async {
    final response = await _http.get(baseUrl.resolve('v1/renders/$id'), headers: _auth);
    return _parse(response, expect: 200);
  }

  /// Creates a render and polls until it succeeds or fails, calling [onUpdate]
  /// with each status. Throws [ApiClientException] on failure or when [timeout]
  /// elapses first.
  Future<RenderJobView> renderAndWait(
    ApiRenderRequest request, {
    void Function(RenderJobView job)? onUpdate,
    Duration pollInterval = const Duration(seconds: 1),
    Duration timeout = const Duration(minutes: 10),
    Future<void> Function(Duration) wait = _realWait,
  }) async {
    final created = await createRender(request);
    onUpdate?.call(created);
    var waited = Duration.zero;
    var latest = created;
    while (latest.isPending) {
      if (waited >= timeout) {
        throw const ApiClientException('Timed out waiting for the render to finish');
      }
      await wait(pollInterval);
      waited += pollInterval;
      latest = await getJob(created.id);
      onUpdate?.call(latest);
    }
    if (latest.isFailed) {
      throw ApiClientException(latest.error ?? 'Render failed');
    }
    return latest;
  }

  /// Statically validates a Playground [code] snippet (analysis only; never
  /// renders). Returns the diagnostics; throws [ApiClientException] on a
  /// non-200 or a malformed response.
  Future<ApiValidationResult> validate(String code) async {
    final response = await _http.post(
      baseUrl.resolve('v1/validate'),
      headers: {'content-type': 'application/json', ..._auth},
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode != 200) {
      throw ApiClientException(_errorMessage(response.body), statusCode: response.statusCode);
    }
    try {
      return ApiValidationResult.fromJson(jsonDecode(response.body) as Map<String, Object?>);
    } on Object {
      throw const ApiClientException('Malformed response from the validate API');
    }
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();

  Map<String, String> get _auth => {if (apiToken != null) 'authorization': 'Bearer $apiToken'};

  RenderJobView _parse(http.Response response, {required int expect}) {
    if (response.statusCode != expect) {
      throw ApiClientException(_errorMessage(response.body), statusCode: response.statusCode);
    }
    try {
      return RenderJobView.fromJson(jsonDecode(response.body) as Map<String, Object?>);
    } on Object {
      throw const ApiClientException('Malformed response from the render API');
    }
  }

  static String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = (decoded['error'] as Map)['message'];
        if (message is String) return message;
      }
    } on FormatException {
      // Fall through to the generic message below.
    }
    return 'Request failed';
  }

  static Future<void> _realWait(Duration duration) => Future<void>.delayed(duration);
}
