part of 'project_handler.dart';

extension _ProjectWrites on ProjectHandler {
  Future<Response> _contribute(Request request, String id) async {
    if (!_guest(request, id)) throw const ApiError.unauthorized();
    final data = await _body(request);
    final name = data['name'];
    if (name is! String || name.isEmpty || name.length > 100) {
      throw const ApiError.badRequest('Enter your name');
    }
    return _serializedWrite(id, () async {
      final project = await _read(id);
      final media = (project['media']! as List<Object?>).cast<Map<String, Object?>>();
      if (media.length > 400) throw const ApiError.badRequest('This album is full');
      final hashes = {for (final item in media) item['hash']};
      final incoming = await _media(data['media'], DateTime.parse(project['expiresAt']! as String));
      final newHashes = {for (final item in incoming) item['hash']}.difference(hashes);
      if (media.length + newHashes.length > 400) {
        throw const ApiError.badRequest('This album is full');
      }
      final duplicates = project['duplicates']! as List<Object?>;
      var added = 0;
      var skipped = 0;
      for (final item in incoming) {
        if (!hashes.add(item['hash'])) {
          duplicates.add({...item, 'by': name, 'kept': false});
          skipped++;
        } else {
          media.add({...item, 'by': name});
          added++;
        }
      }
      project['media'] = media;
      (project['people']! as List<Object?>).add({'name': name, 'added': added, 'skipped': skipped});
      await _save(project);
      return _json({'added': added, 'skipped': skipped});
    });
  }

  Future<Response> _reviewDuplicate(Request request, String id) async {
    if (!_owner(request)) throw const ApiError.unauthorized();
    final data = await _body(request);
    if (data['id'] is! String || data['keepBoth'] is! bool) {
      throw const ApiError.badRequest('Choose a duplicate');
    }
    return _serializedWrite(id, () async {
      final project = await _read(id);
      final duplicates = (project['duplicates']! as List<Object?>).cast<Map<String, Object?>>();
      final matches = duplicates.where((item) => item['id'] == data['id']);
      if (matches.isEmpty) throw const ApiError.notFound();
      final duplicate = matches.first;
      if (duplicate['reviewed'] == true) return _json(project);
      final media = project['media']! as List<Object?>;
      if (data['keepBoth'] == true && media.length >= 400) {
        throw const ApiError.badRequest('This album is full');
      }
      duplicate['reviewed'] = true;
      duplicate['kept'] = data['keepBoth'];
      if (data['keepBoth'] == true) {
        media.add({...duplicate});
      }
      await _save(project);
      return _json(project);
    });
  }

  Future<Response> _serializedWrite(String id, Future<Response> Function() write) async {
    final previous = _writes[id] ?? Future<void>.value();
    final operation = previous.then((_) => write());
    final tail = operation.then<void>((_) {}, onError: (Object _) {});
    _writes[id] = tail;
    try {
      return await operation;
    } finally {
      if (identical(_writes[id], tail)) {
        final removed = _writes.remove(id);
        assert(identical(removed, tail), 'Removed the completed write tail');
      }
    }
  }
}
