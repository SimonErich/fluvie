import 'package:slides/loader/open_fluvie_file.dart';
import 'package:slides/loader/open_fluvie_path_io.dart'
    if (dart.library.js_interop) 'package:slides/loader/open_fluvie_path_web.dart';

/// Reopens a `.fluvie` file by [path] — how a recents entry loads without a
/// picker. Desktop reads the file; the web has no paths (its recents are
/// display-only), so this reports the limitation instead of pretending.
Future<LoadedDeck> openFluvieFileAtPath(String path) => platformOpenFluvieFileAtPath(path);
