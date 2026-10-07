// coverage:ignore-file browser bindings the VM never loads this library
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The object URLs minted for the speaker handoff, one per session value, so
/// repeated Presents reuse them. Session-scoped on purpose: an object URL is
/// origin-wide and stays readable from the same-origin popup until this
/// window revokes it or unloads — exactly the popup's lifetime bound.
final Map<String, ({Uint8List bytes, String url})> _minted = {};

/// An object URL over [bytes] for the session media under [value], minted in
/// this window (the opener) so the speaker popup can fetch the same bytes.
/// Re-minting the same value with the same buffer reuses the URL; replaced
/// bytes revoke the old URL before minting the new one.
String? sessionMediaUrl(String value, Uint8List bytes) {
  final held = _minted[value];
  if (held != null) {
    if (identical(held.bytes, bytes)) return held.url;
    web.URL.revokeObjectURL(held.url);
  }
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
  _minted[value] = (bytes: bytes, url: url);
  return url;
}
