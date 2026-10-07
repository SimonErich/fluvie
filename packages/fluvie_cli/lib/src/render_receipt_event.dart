part of 'render_receipt.dart';

/// Compact machine event referencing the complete on-disk receipt.
/// Full file inventories, raw probe metadata and encode arguments stay on disk.
Map<String, Object?> renderArtifactEvent(Map<String, Object?> receipt) {
  final identity = receipt['output'];
  final output = identity is Map<String, Object?> ? identity : const <String, Object?>{};
  final check = receipt['verification'];
  final verification = check is Map<String, Object?> ? check : const <String, Object?>{};
  return {
    'schemaVersion': 1,
    'event': receipt['event'],
    'filePath': receipt['filePath'],
    'receiptPath': receipt['receiptPath'],
    'sourceFingerprint': receipt['sourceFingerprint'],
    'output': {
      for (final key in ['path', 'kind', 'byteLength', 'sha256', 'media'])
        if (output.containsKey(key)) key: output[key],
    },
    if (verification.isNotEmpty)
      'verification': {
        for (final key in ['ok', 'strictDecode', 'mismatches']) key: verification[key],
      },
    'poster': ?receipt['poster'],
  };
}
