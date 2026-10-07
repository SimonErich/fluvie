// Browser-only stub: web recents carry no reopenable paths, so the picker
// never offers this action there — reaching it is a programming error the
// user still survives.
// coverage:ignore-file
import 'package:slides/loader/open_fluvie_file.dart';

/// The web has no file paths to reopen.
Future<LoadedDeck> platformOpenFluvieFileAtPath(String path) async =>
    LoadedDeck.failed(path, 'Reopening by path is not available in the browser.');
