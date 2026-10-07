/// The package-owned live preview adapter used in the external cached app.
library;

/// Creates a minimal shell around the public Fluvie preview widget.
String previewAppSource({
  required String importLine,
  required String functionName,
  required String title,
  bool localMediaBridge = false,
}) => (localMediaBridge ? _preview : _simplePreview)
    .replaceFirst('{{IMPORT}}', importLine)
    .replaceFirst('{{FUNCTION}}', functionName)
    .replaceFirst(
      '{{TITLE}}',
      title.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$'),
    );

const String _preview = r'''
// Generated Fluvie preview adapter. Edit the original composition instead.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter/services.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';
import 'package:http/http.dart' as http;
{{IMPORT}}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const endpointText = String.fromEnvironment('FLUVIE_PREVIEW_ENDPOINT');
  const token = String.fromEnvironment('FLUVIE_PREVIEW_TOKEN');
  const projectDir = String.fromEnvironment('FLUVIE_PROJECT_DIR');
  final endpoint = endpointText.isEmpty ? null : Uri.parse(endpointText);
  AssetBundle? assets = !kIsWeb && projectDir.isNotEmpty ? ProjectAssetBundle.fromProject(projectDir) : null;
  if (kIsWeb && endpoint != null) {
    final inventory = await http.get(endpoint.resolve('/assets'), headers: {'X-Fluvie-Token': token});
    if (inventory.statusCode != 200) throw StateError('Could not load preview assets (${inventory.statusCode}).');
    final keys = ((jsonDecode(inventory.body) as Map<String, dynamic>)['assets'] as List).cast<String>();
    assets = ProjectAssetBundle(
      assets: keys,
      readAsset: (key) async {
        final response = await http.get(endpoint.resolve('/assets').replace(queryParameters: {'path': key}), headers: {'X-Fluvie-Token': token});
        if (response.statusCode != 200) throw StateError('Preview asset "$key" could not be loaded (${response.statusCode}).');
        return ByteData.sublistView(response.bodyBytes);
      },
      fallback: rootBundle,
    );
  }
  if (kIsWeb && endpoint != null) watchLocalPreviewReloads(endpoint: endpoint, sessionToken: token);
  runApp(MaterialApp(
    title: '{{TITLE}}',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: VideoPreview.builder(
      builder: {{FUNCTION}},
      assetBundle: assets,
      clipDecoder: kIsWeb && endpoint != null
          ? createLocalFfmpegClipDecoder(endpoint: endpoint, sessionToken: token)
          : null,
      audio: kIsWeb && endpoint != null
          ? createLocalPreviewAudioController(endpoint: endpoint, sessionToken: token)
          : null,
    ),
  ));
}
''';

const String _simplePreview = '''
import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
{{IMPORT}}

void main() => runApp(MaterialApp(
  title: '{{TITLE}}',
  debugShowCheckedModeBanner: false,
  theme: ThemeData.dark(useMaterial3: true),
  home: VideoPreview.builder(builder: {{FUNCTION}}),
));
''';
