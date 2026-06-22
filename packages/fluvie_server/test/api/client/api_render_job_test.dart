import 'package:fluvie_server/src/api/client/api_render_job.dart';
import 'package:test/test.dart';

void main() {
  group('RenderJobView', () {
    test('round-trips a succeeded job with links', () {
      final json = {
        'id': 'rnd_1',
        'status': 'succeeded',
        'createdAt': '2026-06-20T10:00:00.000Z',
        'expiresAt': '2026-06-21T10:00:00.000Z',
        'video': {'downloadUrl': 'https://x/v', 'bytes': 100, 'contentType': 'video/mp4'},
        'poster': {'downloadUrl': 'https://x/p'},
      };
      final view = RenderJobView.fromJson(json);
      expect(view.isSucceeded, isTrue);
      expect(view.video!.downloadUrl, Uri.parse('https://x/v'));
      expect(view.video!.bytes, 100);
      expect(view.poster!.downloadUrl, Uri.parse('https://x/p'));
      expect(view.createdAt, DateTime.utc(2026, 6, 20, 10));
      // Re-serializing yields an equivalent shape.
      final round = RenderJobView.fromJson(view.toJson());
      expect(round.video!.downloadUrl, view.video!.downloadUrl);
      expect(round.expiresAt, view.expiresAt);
    });

    test('parses progress and exposes a fraction', () {
      final view = RenderJobView.fromJson(const {
        'id': 'rnd_1',
        'status': 'running',
        'progress': {'completed': 12, 'total': 48},
      });
      expect(view.isPending, isTrue);
      expect(view.completed, 12);
      expect(view.total, 48);
      expect(view.progress, 0.25);
    });

    test('progress is 0 with no total; failed exposes the error', () {
      final queued = RenderJobView.fromJson(const {'id': 'a', 'status': 'queued'});
      expect(queued.progress, 0);
      final failed = RenderJobView.fromJson(const {'id': 'a', 'status': 'failed', 'error': 'boom'});
      expect(failed.isFailed, isTrue);
      expect(failed.error, 'boom');
    });

    test('toJson omits absent fields', () {
      const view = RenderJobView(id: 'a', status: 'queued');
      expect(view.toJson(), {'id': 'a', 'status': 'queued'});
    });
  });
}
