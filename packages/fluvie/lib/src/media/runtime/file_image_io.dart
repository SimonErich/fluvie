import 'dart:io';

import 'package:flutter/widgets.dart';

/// Builds Flutter's async file-image widget for a `file://` source — the native
/// (`dart:io`) side of the live-preview seam. Capture never reaches it (paint
/// reads the decoded cache), so it is untested.
// coverage:ignore-start: live-preview-only dart:io seam; capture never reaches it and a
// unit test does no real file IO.
Widget fileImagePreview(String path, BoxFit? fit) => Image.file(File(path), fit: fit);
// coverage:ignore-end
