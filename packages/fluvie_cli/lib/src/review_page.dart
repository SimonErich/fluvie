import 'dart:convert';

import 'package:fluvie_cli/src/authored_artifacts.dart';
import 'package:path/path.dart' as p;

/// Publishes an offline HTML view of the exact JSON review and local sample PNGs.
/// Text is escaped and sample links are confined to the review directory.
Future<String> writeReviewPage(Map<String, Object?> report, String directory) async {
  const escape = HtmlEscape();
  String text(Object? value) => escape.convert('$value');
  final samples = ((report['samples'] as List?) ?? const []).cast<Map<String, Object?>>();
  final figures = <String>[];
  for (final sample in samples) {
    final file = sample['filePath'];
    if (file is! String || !p.isWithin(p.absolute(directory), p.absolute(file))) continue;
    final path = Uri(path: p.relative(file, from: directory).replaceAll(p.separator, '/'));
    figures.add(
      '<figure> <img src="${text(path)}" alt="Frame ${text(sample['frame'])}">'
      ' <figcaption>Frame ${text(sample['frame'])} · ${text(sample['timeSeconds'])} s</figcaption>  </figure>',
    );
  }
  final path = p.join(directory, 'index.html');
  await atomicWrite(path, '''
<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width"><title>Fluvie review</title>
<style>:root{color-scheme:dark;font:16px system-ui;background:#10141c;color:#edf1fa}
body{max-width:1200px;margin:auto;padding:24px}section{display:flex;gap:16px;flex-wrap:wrap}
figure{margin:0;max-width:360px}img{max-width:100%}pre{white-space:pre-wrap;overflow-wrap:anywhere}
a{color:#96c9ff}</style><body><h1>Review ${report['ok'] == true ? 'passed' : 'failed'}</h1>
<p>${text(report['source'])}<br>Source ${text(report['sourceRevision'])} · ${text(report['backend'])}</p>
<section>${figures.join()}</section><h2>Diagnostics and evidence</h2>
<pre>${text(const JsonEncoder.withIndent('  ').convert(report))}</pre>
<a href="review.json">Structured review</a></body></html>''');
  return path;
}
