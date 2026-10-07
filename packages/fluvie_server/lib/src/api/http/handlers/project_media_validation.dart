part of 'project_handler.dart';

extension _ProjectMediaValidation on ProjectHandler {
  bool _isUploadedMediaUrl(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.hasAuthority &&
      uri.origin == deps.config.publicBaseUrl.origin &&
      uri.pathSegments.length == 3 &&
      uri.pathSegments[0] == 'v1' &&
      uri.pathSegments[1] == 'media';

  Future<List<Map<String, Object?>>> _media(Object? raw, DateTime expires) async {
    if (raw is! List || raw.length > 100) {
      throw const ApiError.badRequest('Choose at most 100 photos');
    }
    final result = <Map<String, Object?>>[];
    for (final value in raw) {
      if (value is! Map<String, Object?> ||
          value['url'] is! String ||
          value['hash'] is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['hash']! as String)) {
        throw const ApiError.badRequest('Invalid media entry');
      }
      final url = Uri.tryParse(value['url']! as String);
      if (url == null || !_isUploadedMediaUrl(url)) {
        throw const ApiError.badRequest('Media must be uploaded to this server');
      }
      final id = url.pathSegments.last;
      if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(id)) {
        throw const ApiError.badRequest('Invalid media id');
      }
      if (value['name'] != null &&
          (value['name'] is! String || (value['name']! as String).length > 240)) {
        throw const ApiError.badRequest('Invalid media name');
      }
      if (value['duration'] != null &&
          (value['duration'] is! String ||
              !RegExp(r'^\d{1,3}:\d{2}$').hasMatch(value['duration']! as String))) {
        throw const ApiError.badRequest('Invalid clip duration');
      }
      if (value['capturedAt'] != null &&
          (value['capturedAt'] is! String ||
              DateTime.tryParse(value['capturedAt']! as String) == null)) {
        throw const ApiError.badRequest('Invalid capture date');
      }
      final grant = deps.signer.verify(url.queryParameters['token'] ?? '', now: deps.now());
      if (grant == null || grant.jobId != id || grant.kind != 'input') {
        throw const ApiError.unauthorized('Invalid media grant');
      }
      final key = 'inputs/$id';
      final object = await deps.fileStore.stat(key);
      if (object == null || object.isExpiredAt(deps.now())) {
        throw const ApiError.gone('Media expired');
      }
      final chunks = await (await deps.fileStore.openRead(key)).expand((part) => part).toList();
      if ('${sha256.convert(chunks)}' != value['hash']) {
        throw const ApiError.badRequest('Media hash mismatch');
      }
      await deps.fileStore.put(
        key,
        Stream.value(chunks),
        contentType: object.contentType,
        visibility: StoreVisibility.private,
        length: object.bytes,
        expiresAt: expires,
      );
      final token = deps.signer.mint(jobId: id, kind: 'input', expiresAt: expires);
      String? poster;
      if (value['poster'] != null) {
        if (value['poster'] is! String) throw const ApiError.badRequest('Invalid poster');
        final uri = Uri.tryParse(value['poster']! as String);
        if (uri == null || !_isUploadedMediaUrl(uri)) {
          throw const ApiError.badRequest('Invalid poster');
        }
        final posterId = uri.pathSegments.last;
        final posterGrant = deps.signer.verify(uri.queryParameters['token'] ?? '', now: deps.now());
        if (posterGrant == null || posterGrant.jobId != posterId || posterGrant.kind != 'input') {
          throw const ApiError.unauthorized('Invalid poster grant');
        }
        final posterKey = 'inputs/$posterId';
        final object = await deps.fileStore.stat(posterKey);
        if (object == null ||
            object.isExpiredAt(deps.now()) ||
            !object.contentType.startsWith('image/')) {
          throw const ApiError.badRequest('Invalid poster image');
        }
        final bytes = await (await deps.fileStore.openRead(
          posterKey,
        )).expand((chunk) => chunk).toList();
        await deps.fileStore.put(
          posterKey,
          Stream.value(bytes),
          contentType: object.contentType,
          visibility: StoreVisibility.private,
          length: bytes.length,
          expiresAt: expires,
        );
        poster =
            '${uri.replace(
              queryParameters: {'token': deps.signer.mint(jobId: posterId, kind: 'input', expiresAt: expires)},
            )}';
      }
      result.add({
        ...value,
        'id': id,
        'url': '${url.replace(queryParameters: {'token': token})}',
        'poster': poster,
      });
    }
    return result;
  }
}
