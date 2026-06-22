import 'package:fluvie_server/src/api/storage/download_grant.dart';
import 'package:fluvie_server/src/api/storage/stored_object.dart';
import 'package:test/test.dart';

void main() {
  group('StoredObject.isExpiredAt', () {
    final created = DateTime.utc(2026, 6, 20, 10);

    StoredObject objectExpiring(DateTime? expiresAt) => StoredObject(
      key: 'rnd/video.mp4',
      bytes: 10,
      contentType: 'video/mp4',
      createdAt: created,
      visibility: StoreVisibility.private,
      expiresAt: expiresAt,
    );

    test('never expires without a TTL', () {
      expect(objectExpiring(null).isExpiredAt(DateTime.utc(3000)), isFalse);
    });

    test('expires at and after expiresAt, not before', () {
      final expiry = created.add(const Duration(hours: 1));
      final object = objectExpiring(expiry);
      expect(object.isExpiredAt(expiry.subtract(const Duration(seconds: 1))), isFalse);
      expect(object.isExpiredAt(expiry), isTrue);
      expect(object.isExpiredAt(expiry.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('DownloadGrant', () {
    test('a stream grant carries no url or expiry', () {
      const grant = DownloadGrant.stream();
      expect(grant.mode, DownloadMode.stream);
      expect(grant.url, isNull);
      expect(grant.expiresAt, isNull);
    });

    test('a redirect grant carries its url and optional expiry', () {
      final until = DateTime.utc(2026, 6, 20, 11);
      final grant = DownloadGrant.redirect(Uri.parse('https://cdn/x.mp4'), expiresAt: until);
      expect(grant.mode, DownloadMode.redirect);
      expect(grant.url, Uri.parse('https://cdn/x.mp4'));
      expect(grant.expiresAt, until);
    });
  });
}
