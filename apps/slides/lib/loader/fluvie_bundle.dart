import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// The deck entry every `.fluvie` bundle holds next to its `media/` folder.
const String fluvieBundleDeckName = 'deck.fluvie.json';

/// The default per-entry size cap (256 MiB), checked before inflation.
const int fluvieBundleEntryCap = 256 << 20;

/// The default whole-bundle size cap (512 MiB), checked before inflation.
const int fluvieBundleTotalCap = 512 << 20;

/// Whether [bytes] start with the zip magic (`PK`) — the one sniff deciding
/// between the two `.fluvie` forms (bundle versus plain JSON).
bool isZipBytes(List<int> bytes) => bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

/// A `.fluvie` bundle that cannot be read: corrupt bytes, a missing deck, an
/// entry outside `media/`, a zip-slip name, or a size past the caps.
final class FluvieBundleException implements Exception {
  /// Creates the failure with its human-readable [message].
  const FluvieBundleException(this.message);

  /// What is wrong with the bundle.
  final String message;

  @override
  String toString() => 'FluvieBundleException: $message';
}

/// Packs [deckJson] plus its [media] (bundle-relative `media/<name>` keys to
/// verbatim bytes) into one `.fluvie` bundle zip.
Uint8List buildFluvieBundle({required String deckJson, required Map<String, Uint8List> media}) {
  final archive = Archive()..addFile(ArchiveFile.string(fluvieBundleDeckName, deckJson));
  media.forEach((name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)));
  return ZipEncoder().encodeBytes(archive);
}

/// Unpacks a `.fluvie` bundle: the deck JSON plus every `media/` entry.
///
/// The unpack is sandboxed: only `media/` entries plus the one deck JSON are
/// read, entry names must be relative with no `..` segments (the zip-slip
/// check), and each entry's declared size is checked against [entryCap] — and
/// their sum against [totalCap] — before any content is touched. Throws a
/// [FluvieBundleException] otherwise.
({String deckJson, Map<String, Uint8List> media}) readFluvieBundle(
  List<int> bytes, {
  int entryCap = fluvieBundleEntryCap,
  int totalCap = fluvieBundleTotalCap,
}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(Uint8List.fromList(bytes));
  } on Object catch (error) {
    throw FluvieBundleException('The bundle zip could not be read: $error');
  }
  String? deckJson;
  var total = 0;
  final files = <ArchiveFile>[];
  for (final file in archive) {
    if (!file.isFile) continue;
    _checkEntryName(file.name);
    if (file.size > entryCap) {
      throw FluvieBundleException(
        'Bundle entry "${file.name}" declares ${file.size} bytes, past the '
        '$entryCap-byte entry cap',
      );
    }
    total += file.size;
    if (total > totalCap) {
      throw FluvieBundleException('The bundle declares more than $totalCap bytes in total');
    }
    files.add(file);
  }
  final media = <String, Uint8List>{};
  for (final file in files) {
    if (file.name == fluvieBundleDeckName) {
      deckJson = utf8.decode(file.content);
    } else {
      media[file.name] = Uint8List.fromList(file.content);
    }
  }
  if (deckJson == null) {
    throw const FluvieBundleException('The bundle holds no $fluvieBundleDeckName');
  }
  return (deckJson: deckJson, media: media);
}

/// A bundle entry is the deck JSON or a relative `media/<name>` path with no
/// traversal: anything else is rejected before inflation.
void _checkEntryName(String name) {
  if (name == fluvieBundleDeckName) return;
  final ok =
      name.startsWith('media/') &&
      name.length > 'media/'.length &&
      !name.contains(r'\') &&
      !name.startsWith('/') &&
      !name.split('/').contains('..');
  if (!ok) {
    throw FluvieBundleException(
      'Bundle entry "$name" is outside media/ (or names a path the unpack '
      'refuses to follow)',
    );
  }
}
