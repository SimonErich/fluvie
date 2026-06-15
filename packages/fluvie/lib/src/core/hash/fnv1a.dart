// FNV-1a-64 offset basis and prime. This hash relies on the VM's 64-bit
// wrapping integer arithmetic and is consumed only by `dart:io`-backed caches —
// no claim of bit-exactness under JS number semantics is made. The basis is
// split into two 32-bit halves to avoid an unsigned 64-bit literal.
const int _fnvOffsetBasis = (0xcbf29ce4 << 32) | 0x84222325;
const int _fnvPrime = 0x100000001b3;

/// The FNV-1a-64 hash of [bytes] as 16 lower-case hex characters.
///
/// In-house on purpose: caches need a fast, deterministic,
/// path-safe key, not cryptographic strength, and this avoids a crypto
/// dependency. The hex form is path-safe by construction. It lives in `core`
/// so both the media/render caches and `core`-resident value types (the
/// snapshot `cacheKey`) can hash without inverting the layering.
String fnv1a64Hex(List<int> bytes) {
  var hash = _fnvOffsetBasis;
  for (final byte in bytes) {
    hash = (hash ^ byte) * _fnvPrime;
  }
  final high = (hash >> 32) & 0xffffffff;
  final low = hash & 0xffffffff;
  return high.toRadixString(16).padLeft(8, '0') + low.toRadixString(16).padLeft(8, '0');
}
