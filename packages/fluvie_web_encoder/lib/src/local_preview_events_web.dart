import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Refreshes after a successful CLI rebuild, including dropped asset changes.
///
/// Browser EventSource reconnects automatically. [onReload] can replace the
/// default page refresh; the returned function closes the session listener.
void Function() watchLocalPreviewReloads({
  required Uri endpoint,
  required String sessionToken,
  void Function()? onReload,
}) {
  final url = endpoint.resolve('/events').replace(queryParameters: {'token': sessionToken});
  final events = web.EventSource(url.toString())
    ..onmessage = ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is! String) return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['type'] == 'reload') {
          if (onReload != null) {
            onReload();
          } else {
            web.window.location.reload();
          }
        }
      } on FormatException {
        // A partial/reconnected event must not interrupt composition playback.
      }
    }).toJS;
  // JS interop extension-type members cannot be torn off in a web build.
  // ignore: unnecessary_lambdas
  return () => events.close();
}
