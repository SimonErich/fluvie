/// Relative-to-document media paths: the desktop save rewrite.
///
/// A deck saved next to its media references it relative to its own folder
/// (`{"kind": "file", "value": "media/intro.mp4"}`), so the folder travels
/// as one portable unit. The values stay relative in the JSON — the loader
/// puts the document's directory into `MediaFileBase` and fluvie resolves
/// them at build time — and the save side lives here: a pure rewrite of the
/// deck JSON against the save target's directory.
library;

import 'package:fluvie/fluvie.dart' show MediaFileBase;

/// The directory holding [path], or null when the path has no separator
/// (a bare file name — the web saver's world).
String? directoryOfPath(String path) {
  final cut = path.lastIndexOf('/') >= 0 ? path.lastIndexOf('/') : path.lastIndexOf(r'\');
  return cut <= 0 ? null : path.substring(0, cut);
}

/// A deep copy of deck [json] with every image and video `file` source
/// under [documentDirectory] rewritten to a directory-relative value.
///
/// Values already relative first absolutize against [base] (the directory
/// the document was loaded from), so a Save-as into another folder keeps
/// pointing at the same files. Paths outside [documentDirectory] stay
/// absolute, and audio sources are never touched — the spec requires an
/// audio `file` path to be absolute.
Map<String, Object?> deckJsonWithRelativeMediaPaths(
  Map<String, Object?> json, {
  required String documentDirectory,
  String? base,
}) => _rewriteNode(json, documentDirectory, base)! as Map<String, Object?>;

/// The holding-object kinds whose `source` is audio and must stay absolute:
/// audio tracks (`music`, `sfx`) and audio store entries.
const Set<String> _audioKinds = {'music', 'sfx', 'audio'};

Object? _rewriteNode(Object? node, String directory, String? base) {
  if (node is Map<String, Object?>) {
    final skipSources = _audioKinds.contains(node['kind']);
    return {
      for (final entry in node.entries)
        entry.key: !skipSources && (entry.key == 'source' || entry.key == 'poster')
            ? _rewriteSource(entry.value, directory, base)
            : _rewriteNode(entry.value, directory, base),
    };
  }
  if (node is List<Object?>) {
    return [for (final item in node) _rewriteNode(item, directory, base)];
  }
  return node;
}

Object? _rewriteSource(Object? source, String directory, String? base) {
  if (source is! Map<String, Object?> || source['kind'] != 'file') {
    return _rewriteNode(source, directory, base);
  }
  final value = source['value'];
  if (value is! String) return _rewriteNode(source, directory, base);
  var absolute = value;
  if (!MediaFileBase.isAbsolute(value)) {
    if (base == null) return {...source};
    absolute = MediaFileBase.join(base, value);
  }
  final prefix = directory.endsWith('/') ? directory : '$directory/';
  return {
    ...source,
    'value': absolute.startsWith(prefix) ? absolute.substring(prefix.length) : absolute,
  };
}
