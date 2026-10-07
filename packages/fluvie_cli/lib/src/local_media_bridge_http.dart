part of 'local_media_bridge.dart';

extension _BridgeHttp on LocalMediaBridge {
  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    var streaming = false;
    try {
      final origin = request.headers.value('origin');
      if (origin != null) {
        final uri = Uri.tryParse(origin);
        if (uri == null || !{'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
          response.statusCode = HttpStatus.forbidden;
          return;
        }
        response.headers.set('Access-Control-Allow-Origin', origin);
        response.headers.set('Vary', 'Origin');
      }
      response.headers.set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
      response.headers.set('Access-Control-Allow-Headers', 'Content-Type,X-Fluvie-Token');
      response.headers.set('Cache-Control', 'no-store');
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        return;
      }
      if ((request.headers.value('X-Fluvie-Token') ?? request.uri.queryParameters['token']) !=
          sessionToken) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final segments = request.uri.pathSegments;
      if (request.method == 'GET' && segments.length == 1 && segments.first == 'events') {
        response
          ..bufferOutput = false
          ..headers.contentType = ContentType('text', 'event-stream');
        streaming = true;
        _events.add(response);
        response.write(
          'data: ${jsonEncode({'type': 'ready', 'audioRevision': audioRevision})}\n\n',
        );
        await response.flush();
        await response.done;
      } else if (request.method == 'GET' && segments.length == 1 && segments.first == 'status') {
        LocalMediaBridge._json(response, {
          'ready': !_closed,
          'audioRevision': audioRevision,
          'sources': _sources.length,
          'decoderStarts': _decoderStarts,
          'activeDecoders': _sessions.length,
        });
      } else if (request.method == 'POST' && segments.length == 1 && segments.first == 'sources') {
        final source = await _register(request);
        LocalMediaBridge._json(response, {
          'id': source.id,
          ...source.info.toJson(),
          'timeline': source.timeline.toJson(),
          'durationSeconds': source.timeline.durationSeconds,
        });
      } else if (request.method == 'POST' &&
          segments.length == 3 &&
          segments.first == 'sources' &&
          segments.last == 'frames') {
        final source = await _sources[segments[1]];
        if (source == null) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        final frames = await _frames(request, source);
        response.headers.contentType = ContentType.binary;
        response.headers.set('X-Fluvie-Indices', frames.keys.join(','));
        streaming = true;
        for (final frame in frames.values) {
          response.add(frame.rgba);
        }
      } else if (request.method == 'GET' && segments.length == 1 && segments.first == 'audio') {
        final provider = _audioProvider;
        if (provider == null) {
          response.statusCode = HttpStatus.notFound;
          LocalMediaBridge._json(response, {'error': 'No audio mix provider is configured.'});
          return;
        }
        final revision = audioRevision;
        final pending = _audio ??= provider();
        final File file;
        try {
          file = await pending;
        } on Object {
          if (identical(_audio, pending)) _audio = null;
          rethrow;
        }
        if (revision != audioRevision) {
          response.statusCode = HttpStatus.conflict;
          return;
        }
        response.headers.contentType = ContentType('audio', 'wav');
        streaming = true;
        await response.addStream(file.openRead());
      } else if (request.method == 'GET' &&
          segments.length == 1 &&
          segments.first == 'assets' &&
          !request.uri.queryParameters.containsKey('path')) {
        final assets = Directory(p.join(projectDir.path, 'assets'));
        final keys = assets.existsSync()
            ? assets
                  .listSync(recursive: true, followLinks: false)
                  .whereType<File>()
                  .map(
                    (file) =>
                        p.relative(file.path, from: projectDir.path).replaceAll(p.separator, '/'),
                  )
                  .toList()
            : <String>[];
        // ignore: cascade_invocations — keys can be discovered or an empty list.
        keys.sort(); // Stable discovery order across filesystems.
        LocalMediaBridge._json(response, {'assets': keys});
      } else if (request.method == 'GET' &&
          segments.isNotEmpty &&
          segments.first == 'assets' &&
          (segments.length > 1 || request.uri.queryParameters.containsKey('path'))) {
        final key = request.uri.queryParameters['path'] ?? segments.skip(1).join('/');
        final path = p.normalize(p.join(projectDir.path, key));
        final root = projectDir.resolveSymbolicLinksSync();
        if (!p.isWithin(p.normalize(projectDir.absolute.path), path) ||
            !File(path).existsSync() ||
            !p.isWithin(root, File(path).resolveSymbolicLinksSync())) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        response.headers.contentType = ContentType.binary;
        streaming = true;
        await response.addStream(File(path).openRead());
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } on Object catch (error) {
      if (!streaming) {
        response.statusCode =
            error is FormatException || error is TypeError || error is ArgumentError
            ? HttpStatus.badRequest
            : HttpStatus.internalServerError;
        LocalMediaBridge._json(response, {'error': error.toString()});
      }
    } finally {
      _events.remove(response);
      try {
        await response.close();
      } on Object {
        /* The client disconnected. */
      }
    }
  }
}
