import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a rendered video file via the platform share sheet.
///
/// A contract (not a typedef) so tests inject a no-op fake.
// ignore: one_member_abstracts
abstract interface class ShareService {
  /// Opens the share sheet for the video at [path].
  Future<void> shareVideo(String path);
}

/// The real share, backed by `share_plus`.
class SharePlusShareService implements ShareService {
  /// Creates the share service.
  const SharePlusShareService();

  @override
  Future<void> shareVideo(String path) =>
      Share.shareXFiles([XFile(path)], text: 'Made with Kitten Mitten');
}

/// The injected share service (overridden with a fake in tests).
final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (ref) => const SharePlusShareService(),
);
