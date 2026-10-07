import 'dart:convert';
import 'dart:math';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:shelf/shelf.dart';

/// Private, expiring inputs for spec renders. Uses the existing store/retention.
final class MediaHandler {
  MediaHandler(this.deps);
  final ServerDependencies deps;
  static const int maxBytes = 64 * 1024 * 1024;
  static const types = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'audio/mp4',
    'audio/mpeg',
    'application/octet-stream',
  };

  Future<Response> upload(Request request) async {
    final bearer = deps.config.apiToken;
    final grant = deps.signer.verify(request.url.queryParameters['token'] ?? '', now: deps.now());
    final guest =
        grant != null &&
        grant.kind == 'contribute' &&
        grant.jobId == request.url.queryParameters['project'];
    if (request.headers['authorization'] != 'Bearer $bearer' && !guest) {
      throw const ApiError.unauthorized();
    }
    final type = request.mimeType ?? 'application/octet-stream';
    if (!types.contains(type)) throw const ApiError.badRequest('Unsupported media type');
    final declared = int.tryParse(request.headers['content-length'] ?? '');
    if (declared != null && declared > maxBytes) throw const ApiError.payloadTooLarge();
    final random = Random.secure();
    final id = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final key = 'inputs/$id';
    final expires = deps.now().add(const Duration(hours: 1));
    var received = 0;
    Stream<List<int>> bounded() async* {
      await for (final chunk in request.read()) {
        received += chunk.length;
        if (received > maxBytes) throw const ApiError.payloadTooLarge();
        yield chunk;
      }
      if (received == 0) throw const ApiError.badRequest('Empty media');
    }

    try {
      await deps.fileStore.put(
        key,
        bounded(),
        contentType: type,
        visibility: StoreVisibility.private,
        length: declared,
        expiresAt: expires,
      );
    } on Object {
      await deps.fileStore.delete(key);
      rethrow;
    }
    final token = deps.signer.mint(jobId: id, kind: 'input', expiresAt: expires);
    final url = deps.config.publicBaseUrl
        .resolve('v1/media/$id')
        .replace(queryParameters: {'token': token});
    return Response(
      201,
      body: jsonEncode({'url': '$url', 'expiresAt': expires.toIso8601String()}),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> download(Request request, String id) async {
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(id)) throw const ApiError.notFound();
    final grant = deps.signer.verify(request.url.queryParameters['token'] ?? '', now: deps.now());
    if (grant == null || grant.jobId != id || grant.kind != 'input') {
      throw const ApiError.unauthorized();
    }
    final object = await deps.fileStore.stat('inputs/$id');
    if (object == null || object.expiresAt != null && !deps.now().isBefore(object.expiresAt!)) {
      throw const ApiError.gone();
    }
    return Response.ok(
      await deps.fileStore.openRead('inputs/$id'),
      headers: {'content-type': object.contentType, 'content-length': '${object.bytes}'},
    );
  }
}
