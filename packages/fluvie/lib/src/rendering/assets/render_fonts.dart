import 'dart:convert';

import 'package:flutter/services.dart';

/// The stable default shared by preview and capture. Explicit styles win.
const fluvieDefaultFontFamily = 'packages/fluvie/Fluvie Sans';

/// Loads the project's actual font manifest into a capture or preview engine.
///
/// Flutter test engines otherwise use Ahem. Package family names are retained,
/// so a normal `TextStyle(package: ..., fontFamily: ...)` resolves identically.
Future<void> loadRenderFonts({AssetBundle? bundle}) async {
  final assets = bundle ?? rootBundle;
  final manifest = jsonDecode(await assets.loadString('FontManifest.json')) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(assets.load(font['asset'] as String));
    }
    await loader.load();
    // The package's own examples build a manifest without the package prefix.
    // Alias only this bundled family; consumer family names remain untouched.
    if (entry['family'] == 'Fluvie Sans') {
      final alias = FontLoader(fluvieDefaultFontFamily);
      for (final font in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        alias.addFont(assets.load(font['asset'] as String));
      }
      await alias.load();
    }
  }
}
