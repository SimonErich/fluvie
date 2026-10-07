import 'dart:typed_data';

/// Non-web platforms have no speaker popup, so nothing mints session URLs;
/// the payload rewrite falls back to the asset form.
String? sessionMediaUrl(String value, Uint8List bytes) => null;
