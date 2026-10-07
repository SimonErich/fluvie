import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show DefaultAssetBundle, FlutterError;
import 'package:fluvie/src/rendering/assets/project_asset_files_stub.dart'
    if (dart.library.io) 'package:fluvie/src/rendering/assets/project_asset_files_io.dart';

/// Reads one logical project asset, such as `assets/cat/first_day.jpg`.
typedef ProjectAssetReader = Future<ByteData> Function(String key);

/// Adds a project's dropped assets to its original Flutter asset bundle.
///
/// Use the same bundle in [DefaultAssetBundle] and the media resolver. Existing
/// package assets, fonts, shaders and resolution-aware variants remain intact.
/// Direct `rootBundle` calls retain Flutter's normal declared-asset behavior.
final class ProjectAssetBundle extends CachingAssetBundle {
  /// Creates a bundle over an inventory and its reader (also usable on web).
  ProjectAssetBundle({
    required Iterable<String> assets,
    required ProjectAssetReader readAsset,
    AssetBundle? fallback,
  }) : _assets = Set.unmodifiable(assets.map(_key)),
       // The public reader argument stays named readAsset; it is not a mutable property.
       // ignore: prefer_initializing_formals
       _readAsset = readAsset,
       _fallback = fallback ?? rootBundle;

  final Set<String> _assets;
  final ProjectAssetReader _readAsset;
  final AssetBundle _fallback;
  Future<ByteData>? _manifest;

  /// Recursively discovers `assets/` without changing the project's pubspec.
  /// On web, provide an inventory and reader through the regular constructor.
  static Future<ProjectAssetBundle> fromProject(String projectDir, {AssetBundle? fallback}) async {
    final files = await discoverProjectAssets(projectDir);
    return ProjectAssetBundle(assets: files.keys, readAsset: files.read, fallback: fallback);
  }

  /// Logical keys discovered in the project's assets directory.
  Set<String> get projectAssets => _assets;

  static String _key(String value) {
    final key = value.replaceAll(r'\', '/');
    if (key.startsWith('/') || key.split('/').contains('..')) {
      throw ArgumentError.value(value, 'assets', 'must be a relative asset key');
    }
    return key;
  }

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') return _manifest ??= _buildManifest();
    if (key == 'AssetManifest.bin.json') {
      final bytes = await (_manifest ??= _buildManifest());
      return ByteData.sublistView(
        Uint8List.fromList(
          utf8.encode(
            jsonEncode(
              base64Encode(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return _assets.contains(key) ? _readAsset(key) : _fallback.load(key);
  }

  Future<ByteData> _buildManifest() async {
    final entries = <Object?, Object?>{};
    try {
      final ByteData original;
      if (kIsWeb) {
        final encoded = jsonDecode(await _fallback.loadString('AssetManifest.bin.json')) as String;
        original = ByteData.sublistView(base64Decode(encoded));
      } else {
        original = await _fallback.load('AssetManifest.bin');
      }
      entries.addAll(
        const StandardMessageCodec().decodeMessage(original)! as Map<Object?, Object?>,
      );
      // Flutter's AssetBundle uses FlutterError for missing manifests.
      // ignore: avoid_catching_errors
    } on FlutterError {
      // A standalone host may have no declared assets yet.
    }
    final variantPattern = RegExp(r'^(.*\/)?([0-9]+(?:\.[0-9]+)?)x\/([^/]+)$');
    final grouped = <String, List<Map<String, Object>>>{};
    for (final key in _assets.toList()..sort()) {
      final match = variantPattern.firstMatch(key);
      final logical = match == null ? key : '${match[1] ?? ''}${match[3]}';
      grouped.putIfAbsent(logical, () => []).add({
        'asset': key,
        if (match != null) 'dpr': double.parse(match[2]!),
      });
    }
    for (final entry in grouped.entries) {
      final variants = <Object?>[...?entries[entry.key] as List<Object?>?];
      final existing = {
        for (final variant in variants) (variant! as Map<Object?, Object?>)['asset'],
      };
      variants.addAll(entry.value.where((variant) => !existing.contains(variant['asset'])));
      entries[entry.key] = variants;
    }
    return const StandardMessageCodec().encodeMessage(entries)!;
  }
}
