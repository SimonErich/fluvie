import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/rendering/render_host.dart';

/// Runs serial requests in one Flutter engine until a stop request arrives.
///
/// The launcher owns [mailbox] and publishes `request.json` by atomic rename.
/// Each request has a unique `id` and an `invocation` object understood by
/// [RenderInvocation.fromJson]. Responses are published as `response.json`.
/// The composition is rebuilt and resources are released after each request;
/// compilation and the Flutter engine stay warm. Source edits require retiring
/// the process. This protocol is local and does not sandbox authored Dart.
Future<void> runFluvieWorker({
  required FutureOr<Video> Function() videoFactory,
  required RenderHostContext Function() hostFactory,
  required Directory mailbox,
}) async {
  final root = mailbox.absolute.path;
  final waiter = hostFactory();
  await waiter.runAsync(() async {
    await mailbox.create(recursive: true);
    await _publishWorker(File('$root/ready.json'), {'schemaVersion': 1, 'pid': pid});
    return null;
  });
  while (true) {
    final request = await waiter.runAsync(() => _nextWorkerRequest(File('$root/request.json')));
    if (request == null) throw StateError('The worker received no request.');
    if (request['stop'] == true) return;
    final id = request['id'];
    final watch = Stopwatch()..start();
    Map<String, Object?> result;
    try {
      if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
        throw ArgumentError('A request needs a unique alphanumeric id.');
      }
      final json = request['invocation'];
      if (json is! Map<String, Object?>) throw ArgumentError('invocation must be an object.');
      final invocation = RenderInvocation.fromJson(json);
      final host = hostFactory();
      Video? video;
      Object? failure;
      StackTrace? trace;
      await host.runAsync(() async {
        try {
          video = await videoFactory();
        } on Object catch (error, stack) {
          failure = error;
          trace = stack;
        }
        return null;
      });
      if (failure != null) Error.throwWithStackTrace(failure!, trace!);
      if (video == null) throw StateError('The entry returned no Video.');
      await runFluvieRender(
        video: video!,
        host: host,
        invocation: invocation,
        videoFactory: videoFactory,
      );
      result = {'id': id, 'ok': true};
    } on Object catch (error) {
      result = {'id': id, 'ok': false, 'error': '$error'};
    }
    await waiter.runAsync(() async {
      await _publishWorker(File('$root/response.json'), {
        'schemaVersion': 1,
        ...result,
        'elapsedMilliseconds': watch.elapsedMilliseconds,
        'backend': 'flutter-test',
      });
      return null;
    });
  }
}

Future<Map<String, Object?>> _nextWorkerRequest(File file) async {
  while (!file.existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  if (await file.length() > 65536) throw ArgumentError('Worker requests are limited to 64 KiB.');
  final value = jsonDecode(await file.readAsString());
  await file.delete();
  if (value is! Map<String, Object?>) throw ArgumentError('A worker request must be an object.');
  return value;
}

Future<void> _publishWorker(File file, Map<String, Object?> value) async {
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(jsonEncode(value), flush: true);
  await temporary.rename(file.path);
}
