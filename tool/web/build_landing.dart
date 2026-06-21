import 'dart:convert';
import 'dart:io';

/// Fills the data-driven regions of the marketing landing
/// (`web/landing/index.html`) from `web/landing/landing_data.json`: the package
/// list and the lesson gallery. This replaces the old LLM reconcile with a
/// deterministic build, so the page is pure static output.
///
/// Usage:
///   dart run tool/web/build_landing.dart           # rewrite index.html
///   dart run tool/web/build_landing.dart --check   # CI: fail on drift, no writes
///
/// It also validates the data against the workspace: every published `packages/*`
/// must have a package entry and vice versa, and every `example/lib/lessons/NN_*`
/// must have a lesson entry and vice versa. A mismatch is a hard error, so adding
/// a package or a lesson without updating the site fails the build.
void main(List<String> args) {
  final check = args.contains('--check');
  final dataFile = File('web/landing/landing_data.json');
  final htmlFile = File('web/landing/index.html');
  if (!dataFile.existsSync() || !htmlFile.existsSync()) {
    stderr.writeln('error: run from the repo root (web/landing/ not found).');
    exit(1);
  }

  final data = jsonDecode(dataFile.readAsStringSync()) as Map<String, Object?>;
  final packages = (data['packages']! as List).cast<Map<String, Object?>>();
  final lessons = (data['lessons']! as List).cast<Map<String, Object?>>();

  final errors = <String>[
    ..._validatePackages(packages),
    ..._validateLessons(lessons),
  ];
  if (errors.isNotEmpty) {
    for (final e in errors) {
      stderr.writeln('error: $e');
    }
    exit(1);
  }

  final current = htmlFile.readAsStringSync();
  var next = _replaceRegion(
    current,
    '<!-- region:packages',
    '<!-- /region:packages -->',
    _packagesHtml(packages),
  );
  next = _replaceRegion(
    next,
    '// #region:gallery',
    '// #endregion:gallery',
    _galleryJs(lessons),
  );
  next = next.replaceFirst(
    RegExp('<!--pkgcount-->.*?<!--/pkgcount-->'),
    '<!--pkgcount-->${_countWord(packages.length)}<!--/pkgcount-->',
  );

  if (check) {
    if (next == current) {
      stdout.writeln('web:landing:check — index.html is in sync with landing_data.json.');
    } else {
      stderr.writeln(
        'web:landing:check — index.html is out of sync. Run `melos run web:landing`.',
      );
      exit(2);
    }
    return;
  }

  if (next == current) {
    stdout.writeln('web:landing — nothing to update.');
  } else {
    htmlFile.writeAsStringSync(next);
    stdout.writeln('web:landing — regenerated web/landing/index.html.');
  }
}

/// Replaces the text between the line carrying [startMarker] and the line
/// carrying [endMarker] with [body] (which ends in a newline), keeping both
/// marker lines and the end marker's indentation.
String _replaceRegion(String src, String startMarker, String endMarker, String body) {
  final start = src.indexOf(startMarker);
  final end = src.indexOf(endMarker, start);
  if (start < 0 || end < 0) {
    stderr.writeln('error: missing region marker "$startMarker" / "$endMarker".');
    exit(1);
  }
  final afterStartLine = src.indexOf('\n', start) + 1;
  final endLineStart = src.lastIndexOf('\n', end) + 1;
  return src.substring(0, afterStartLine) + body + src.substring(endLineStart);
}

String _packagesHtml(List<Map<String, Object?>> packages) {
  final buffer = StringBuffer();
  for (final pkg in packages) {
    final key = pkg['key']! as String;
    final role = pkg['role']! as String;
    final line = pkg['line']! as String;
    final icon = pkg['icon']! as String;
    final primary = pkg['primary'] == true;
    final badge = pkg['badge'] as String?;
    final rowStyle = primary
        ? 'border:1px solid rgba(22,104,227,0.3); background:linear-gradient(120deg,#F4F9FF,#EAF2FF);'
        : 'border:1px solid var(--line); background:#fff;';
    final iconStyle = primary
        ? 'background:var(--grad); color:#fff;'
        : 'background:#EEF3FD; color:var(--acc);';
    final badgeHtml = badge == null
        ? ''
        : '<span style="font-size:9.5px; font-weight:700; letter-spacing:0.04em; color:#fff; background:var(--acc); padding:2px 7px; border-radius:5px;">${_escText(badge)}</span>';
    buffer
      ..writeln('        <li>')
      ..writeln(
        '          <a href="https://pub.dev/packages/$key" aria-label="$key, ${_escAttr(role)}, opens pub.dev (external)" class="flv-pkg-row" style="display:grid; grid-template-columns:52px 200px 1fr auto; gap:20px; align-items:center; text-decoration:none; color:inherit; border-radius:16px; $rowStyle padding:20px 24px; transition:transform .25s ease, box-shadow .25s ease, border-color .25s ease;" style-hover="transform:translateX(4px); box-shadow:0 18px 40px -26px rgba(22,104,227,0.3); border-color:#BFE6FF;">',
      )
      ..writeln(
        '            <span aria-hidden="true" style="display:inline-flex; width:52px; height:52px; align-items:center; justify-content:center; border-radius:14px; font-size:22px; $iconStyle">$icon</span>',
      )
      ..writeln('            <div>')
      ..writeln(
        '              <div style="display:flex; align-items:center; gap:8px;"><span style="font-family:\'JetBrains Mono\',monospace; font-weight:700; font-size:16px; color:var(--ink);">$key</span>$badgeHtml</div>',
      )
      ..writeln(
        '              <div style="font-size:12.5px; color:var(--muted); margin-top:3px;">${_escText(role)}</div>',
      )
      ..writeln('            </div>')
      ..writeln(
        '            <div class="flv-pkg-line" style="font-size:14px; color:var(--soft); line-height:1.5;">${_escText(line)}</div>',
      )
      ..writeln(
        '            <span class="flv-pkg-chip" aria-hidden="true" style="display:inline-flex; align-items:center; gap:7px; font-size:12.5px; font-weight:600; color:var(--acc); white-space:nowrap;">pub.dev <span style="font-size:11px;">&#8599;</span></span>',
      )
      ..writeln('          </a>')
      ..writeln('        </li>');
  }
  return buffer.toString();
}

String _galleryJs(List<Map<String, Object?>> lessons) {
  final rows = lessons
      .map((l) {
        final key = jsonEncode(l['key']);
        final title = jsonEncode(l['title']);
        final teaches = jsonEncode(l['teaches']);
        final category = jsonEncode(l['category']);
        final clip = l['clip'] == true;
        return '    [$key, $title, $teaches, $category, $clip]';
      })
      .join(',\n');
  return '  var GAL = [\n$rows\n  ];\n';
}

List<String> _validatePackages(List<Map<String, Object?>> packages) {
  final dataKeys = packages.map((p) => p['key']! as String).toSet();
  final published = <String>{};
  final dir = Directory('packages');
  for (final entry in dir.listSync().whereType<Directory>()) {
    final pubspec = File('${entry.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final text = pubspec.readAsStringSync();
    if (RegExp(r'''^\s*publish_to:\s*["']?none''', multiLine: true).hasMatch(text)) continue;
    published.add(entry.uri.pathSegments[entry.uri.pathSegments.length - 2]);
  }
  return [
    for (final k in published.difference(dataKeys))
      'published package "$k" has no entry in landing_data.json (add it to the site).',
    for (final k in dataKeys.difference(published))
      'landing_data.json lists "$k" but no such published packages/$k exists.',
  ];
}

List<String> _validateLessons(List<Map<String, Object?>> lessons) {
  final dataKeys = lessons.map((l) => l['key']! as String).toSet();
  final onDisk = <String>{};
  final dir = Directory('example/lib/lessons');
  if (dir.existsSync()) {
    for (final file in dir.listSync().whereType<File>()) {
      final match = RegExp(r'(\d\d)_.*\.dart$').firstMatch(file.path);
      if (match != null) onDisk.add(match.group(1)!);
    }
  }
  return [
    for (final k in onDisk.difference(dataKeys))
      'lesson "$k" exists under example/lib/lessons but has no gallery entry.',
    for (final k in dataKeys.difference(onDisk))
      'landing_data.json lists lesson "$k" but no such example/lib/lessons/${k}_*.dart exists.',
  ];
}

String _countWord(int n) {
  const words = [
    'Zero',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
  ];
  return (n >= 0 && n < words.length) ? words[n] : '$n';
}

String _escAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _escText(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
