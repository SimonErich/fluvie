import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:fluvie_server/src/api/http/api_error.dart';
import 'package:fluvie_server/src/api/http/server_dependencies.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:shelf/shelf.dart';

part 'project_media_validation.dart';
part 'project_writes.dart';

/// Optional collaborative photo collections; link holders can contribute only.
/// Owner reads use the API bearer, guests use a scoped, expiring signed token.
final class ProjectHandler {
  ProjectHandler(this.deps);
  final ServerDependencies deps;
  final Map<String, Future<void>> _writes = {};
  static const int bodyLimit = 1024 * 1024;

  bool _owner(Request request) =>
      request.headers['authorization'] == 'Bearer ${deps.config.apiToken}';
  bool _guest(Request request, String id) {
    final grant = deps.signer.verify(request.url.queryParameters['token'] ?? '', now: deps.now());
    return grant != null && grant.jobId == id && grant.kind == 'contribute';
  }

  String _id() {
    final random = Random.secure();
    return List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Map<String, Object?>> _body(Request request) async {
    final bytes = <int>[];
    await for (final chunk in request.read()) {
      if (bytes.length + chunk.length > bodyLimit) throw const ApiError.payloadTooLarge();
      bytes.addAll(chunk);
    }
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } on Object {
      throw const ApiError.badRequest('Expected a JSON object');
    }
  }

  Future<Map<String, Object?>> _read(String id) async {
    if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(id)) throw const ApiError.notFound();
    final key = 'projects/$id';
    final object = await deps.fileStore.stat(key);
    if (object == null || object.isExpiredAt(deps.now())) {
      throw const ApiError.gone('Invitation expired');
    }
    final bytes = await (await deps.fileStore.openRead(key)).expand((chunk) => chunk).toList();
    return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  }

  Future<void> _save(Map<String, Object?> project) async {
    final bytes = utf8.encode(jsonEncode(project));
    await deps.fileStore.put(
      'projects/${project['id']}',
      Stream.value(bytes),
      contentType: 'application/json',
      visibility: StoreVisibility.private,
      length: bytes.length,
      expiresAt: DateTime.parse(project['expiresAt']! as String),
    );
  }

  Response _json(Map<String, Object?> value, [int status = 200]) =>
      Response(status, body: jsonEncode(value), headers: {'content-type': 'application/json'});
  Future<Response> create(Request request) async {
    if (!_owner(request)) throw const ApiError.unauthorized('Collaboration requires an API token');
    final data = await _body(request);
    final name = data['owner'];
    final title = data['title'];
    if (name is! String ||
        name.isEmpty ||
        name.length > 100 ||
        title is! String ||
        title.length > 240) {
      throw const ApiError.badRequest('Invalid project details');
    }
    final id = _id();
    final expires = deps.now().add(const Duration(hours: 24));
    final project = <String, Object?>{
      'id': id,
      'title': title,
      'owner': name,
      'expiresAt': expires.toIso8601String(),
      'people': <Object?>[],
      'media': await _media(data['media'], expires),
      'duplicates': <Object?>[],
    };
    await _save(project);
    final token = deps.signer.mint(jobId: id, kind: 'contribute', expiresAt: expires);
    return _json({...project, 'guestToken': token}, 201);
  }

  Future<Response> get(Request request, String id) async {
    if (!_owner(request) && !_guest(request, id)) throw const ApiError.unauthorized();
    final project = await _read(id);
    if (!_owner(request)) {
      return _json({
        'id': id,
        'title': project['title'],
        'owner': project['owner'],
        'hashes': [
          for (final item in (project['media']! as List<Object?>).cast<Map<String, Object?>>())
            item['hash'],
        ],
        'expiresAt': project['expiresAt'],
      });
    }
    return _json(project);
  }

  Future<Response> contribute(Request request, String id) => _contribute(request, id);

  Future<Response> reviewDuplicate(Request request, String id) => _reviewDuplicate(request, id);
}
