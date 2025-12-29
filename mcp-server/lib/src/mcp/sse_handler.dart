import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Handler for Server-Sent Events (SSE) connections
class SseHandler {
  /// Handle an SSE connection request
  Response handleSse(Request request, Stream<String> eventStream) {
    final controller = StreamController<List<int>>();

    eventStream.listen(
      (event) {
        final sseMessage = 'data: $event\n\n';
        controller.add(utf8.encode(sseMessage));
      },
      onDone: () => controller.close(),
      onError: (Object e) => controller.addError(e),
    );

    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  /// Send a keep-alive ping
  static String createPing() {
    return jsonEncode(
      {'type': 'ping', 'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Create an event message
  static String createEvent(String eventType, Map<String, dynamic> data) {
    return jsonEncode({
      'type': eventType,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
