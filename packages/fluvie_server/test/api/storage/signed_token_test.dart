import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fluvie_server/src/api/storage/signed_token.dart';
import 'package:test/test.dart';

/// Builds a correctly-signed token for [payload] under [secret], so tests can
/// reach the post-signature validation branches with a valid digest.
String _signed(List<int> secret, String payload) {
  final digest = base64Url.encode(Hmac(sha256, secret).convert(utf8.encode(payload)).bytes);
  return '${base64Url.encode(utf8.encode(payload))}.$digest';
}

void main() {
  const key = [1, 2, 3, 4];
  const signer = DownloadTokenSigner(key);
  final now = DateTime.utc(2026, 6, 20, 10);
  final later = now.add(const Duration(minutes: 15));

  group('DownloadTokenSigner', () {
    test('a freshly minted token verifies to its job and kind', () {
      final token = signer.mint(jobId: 'rnd_1', kind: 'video', expiresAt: later);
      expect(signer.verify(token, now: now), (jobId: 'rnd_1', kind: 'video'));
    });

    test('rejects an expired token (at and past expiry)', () {
      final token = signer.mint(jobId: 'rnd_1', kind: 'video', expiresAt: now);
      expect(signer.verify(token, now: now), isNull);
      expect(signer.verify(token, now: now.add(const Duration(seconds: 1))), isNull);
    });

    test('rejects a token signed with a different key', () {
      final token = signer.mint(jobId: 'rnd_1', kind: 'video', expiresAt: later);
      const other = DownloadTokenSigner([9, 9, 9]);
      expect(other.verify(token, now: now), isNull);
    });

    test('rejects a tampered payload (digest no longer matches)', () {
      final token = signer.mint(jobId: 'rnd_1', kind: 'video', expiresAt: later);
      final digest = token.substring(token.indexOf('.'));
      final forged = '${base64Url.encode(utf8.encode('rnd_2:video:99999999999999'))}$digest';
      expect(signer.verify(forged, now: now), isNull);
    });

    test('rejects malformed tokens', () {
      expect(signer.verify('', now: now), isNull);
      expect(signer.verify('nodot', now: now), isNull);
      expect(signer.verify('.onlydigest', now: now), isNull);
      expect(signer.verify('payload.', now: now), isNull);
      // A first segment that is not valid base64url cannot be decoded.
      expect(signer.verify('%%%.${base64Url.encode(utf8.encode('x'))}', now: now), isNull);
    });

    test('rejects a validly-signed payload with the wrong field count', () {
      expect(signer.verify(_signed(key, 'rnd_1:video'), now: now), isNull);
    });

    test('rejects a validly-signed payload with a non-integer expiry', () {
      expect(signer.verify(_signed(key, 'rnd_1:video:notanumber'), now: now), isNull);
    });
  });
}
