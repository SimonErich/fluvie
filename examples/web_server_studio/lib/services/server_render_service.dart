import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_server/client.dart';

/// Why a server render failed, so the UI can show a precise message.
enum ServerRenderErrorKind {
  /// The server rejected the API token (401/403).
  auth,

  /// The render took too long.
  timeout,

  /// A network or other server error.
  network,
}

/// A friendly failure from the render server.
class ServerRenderException implements Exception {
  /// Creates a render failure with a [message] and a [kind].
  const ServerRenderException(
    this.message, {
    this.kind = ServerRenderErrorKind.network,
  });

  /// The user-facing message.
  final String message;

  /// The failure category.
  final ServerRenderErrorKind kind;

  @override
  String toString() => message;
}

/// Submits a VideoSpec to the Fluvie render server and waits for the MP4.
///
/// A contract (not a typedef) so it is injected via Riverpod and faked in tests.
// ignore: one_member_abstracts
abstract interface class ServerRenderService {
  /// Renders [spec] on the server at [baseUrl], returning the video download URL.
  Future<Uri> render({
    required Uri baseUrl,
    required Map<String, Object?> spec,
    String? apiToken,
    void Function(double progress)? onProgress,
  });
}

/// The real service, backed by [ApiRenderClient].
class ApiServerRenderService implements ServerRenderService {
  /// Creates the API-backed render service.
  const ApiServerRenderService();

  @override
  Future<Uri> render({
    required Uri baseUrl,
    required Map<String, Object?> spec,
    String? apiToken,
    void Function(double progress)? onProgress,
  }) async {
    final client = ApiRenderClient(baseUrl: baseUrl, apiToken: apiToken);
    try {
      final job = await client.renderAndWait(
        ApiRenderRequest.spec(spec),
        onUpdate: (view) => onProgress?.call(view.progress),
        timeout: const Duration(minutes: 5),
      );
      final video = job.video;
      if (video == null) {
        throw const ServerRenderException(
          'The server finished but returned no video.',
        );
      }
      return video.downloadUrl;
    } on ApiClientException catch (error) {
      throw ServerRenderException(_message(error), kind: _kind(error));
    } finally {
      client.close();
    }
  }

  static ServerRenderErrorKind _kind(ApiClientException error) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return ServerRenderErrorKind.auth;
    }
    if (error.message.toLowerCase().contains('timed out')) {
      return ServerRenderErrorKind.timeout;
    }
    return ServerRenderErrorKind.network;
  }

  static String _message(ApiClientException error) => switch (_kind(error)) {
    ServerRenderErrorKind.auth => 'The server rejected your API token. Check it and try again.',
    ServerRenderErrorKind.timeout => 'The render timed out. Try again or simplify the promo.',
    ServerRenderErrorKind.network => error.message,
  };
}

/// The injected render service (overridden with a fake in tests).
final Provider<ServerRenderService> serverRenderServiceProvider = Provider<ServerRenderService>(
  (ref) => const ApiServerRenderService(),
);
