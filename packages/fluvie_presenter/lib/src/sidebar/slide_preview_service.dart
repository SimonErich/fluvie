import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One queued render: the slide to draw and the future the caller holds.
typedef _QueuedRender = ({int slide, Completer<ui.Image> completer});

/// Renders slide previews lazily and caches them as images — off the
/// critical path, capped, and shared by the sidebar and the overview grid so
/// nothing renders twice.
///
/// The actual pixels come from the injected [renderSlide] (in production a
/// hidden stage renders the slide's settled final state; tests inject a
/// fake). Requests deduplicate while in flight, run at most [concurrency] at
/// a time, and land in an LRU cache of [capacity] images. Listeners are
/// notified whenever a preview arrives, so tiles can show a placeholder and
/// repaint when ready.
///
/// A host may be torn down while previews are still rendering, so [dispose]
/// is safe at any moment: see it for what happens to the work in flight.
///
/// The service owns every image it caches and releases it on eviction, on
/// [invalidate], and on [dispose]. [peek] and [preview] lend that handle:
/// callers never dispose it and never hold it past the next drop. Painting
/// one stays safe either way, because `RawImage` clones what it shows, so a
/// tile on screen keeps its pixels even after the cache lets go.
final class SlidePreviewService extends ChangeNotifier {
  /// Creates the service around [renderSlide].
  SlidePreviewService({required this.renderSlide, this.capacity = 32, this.concurrency = 2})
    : assert(capacity > 0, 'capacity must be > 0'),
      assert(concurrency > 0, 'concurrency must be > 0');

  /// Produces the preview image for one slide index.
  final Future<ui.Image> Function(int slide) renderSlide;

  /// How many previews the cache keeps before evicting the least recently
  /// used.
  final int capacity;

  /// How many renders may run at once; the rest queue.
  final int concurrency;

  final LinkedHashMap<int, ui.Image> _cache = LinkedHashMap();
  final Map<int, Future<ui.Image>> _inFlight = {};
  final Queue<_QueuedRender> _queue = Queue();
  int _running = 0;
  bool _disposed = false;

  /// The cached preview for [slide], or `null` when it has not rendered yet.
  /// Peeking refreshes the entry's recency.
  ///
  /// The image stays the service's to release; paint it, don't keep it.
  ui.Image? peek(int slide) {
    final image = _cache.remove(slide);
    if (image == null) return null;
    return _cache[slide] = image;
  }

  /// The preview for [slide]: served from the cache, joined onto an
  /// in-flight render, or queued behind the concurrency cap.
  ///
  /// The image is the service's, on the same terms as [peek] — except for a
  /// render that lands after [dispose], which has no cache left to live in
  /// and becomes the caller's to release.
  ///
  /// After [dispose] the returned future fails with a [StateError] rather
  /// than starting a render, so a late tile rebuild never waits forever.
  Future<ui.Image> preview(int slide) {
    final cached = peek(slide);
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[slide];
    if (pending != null) return pending;
    if (_disposed) return Future<ui.Image>.error(_disposedError(slide), StackTrace.current);
    final completer = Completer<ui.Image>();
    _inFlight[slide] = completer.future;
    _queue.add((slide: slide, completer: completer));
    _pump();
    return completer.future;
  }

  /// Warms the cache for every slide of a [slideCount]-slide deck, in order.
  ///
  /// Warming is best effort: a slide that fails to render, and every slide
  /// abandoned by a [dispose] mid-warm-up, is skipped rather than reported —
  /// nobody is waiting on a head start, and a dropped failure must not land
  /// on the zone as an unhandled error.
  Future<void> pregenerateAll(int slideCount) => Future.wait([
    for (var s = 0; s < slideCount; s++) preview(s).then<void>((_) {}, onError: (Object _) {}),
  ]);

  /// Drops every cached preview (and their recency) so content changes
  /// re-render, releasing the images with it. In-flight renders still land.
  void invalidate() {
    _releaseCache();
    _notify();
  }

  /// Retires the service: the cached images are released, renders already
  /// running still deliver their image to whoever awaited them, renders
  /// still queued are abandoned and their futures fail with a [StateError],
  /// no new render starts, and listeners are never notified again.
  ///
  /// Every pending future therefore settles one way or the other, so a host
  /// that closes mid-render (a slide edited, then navigated away from, then
  /// the deck closed) leaves nothing hanging and nothing to throw.
  @override
  void dispose() {
    _disposed = true;
    _releaseCache();
    while (_queue.isNotEmpty) {
      final abandoned = _queue.removeFirst();
      // remove() hands back the stored future; nothing awaits it here.
      unawaited(_inFlight.remove(abandoned.slide));
      abandoned.completer.completeError(_disposedError(abandoned.slide), StackTrace.current);
    }
    super.dispose();
  }

  /// Notification is a courtesy to living listeners: a disposed notifier
  /// throws on [notifyListeners], and that throw must never reach a render.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Empties the cache, releasing each image the service still owns. A tile
  /// painting one of them holds its own clone, so its pixels survive.
  void _releaseCache() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
  }

  /// Stores [image] as [slide]'s preview, releasing whatever the cap pushes
  /// out — the service owns what it caches.
  void _store(int slide, ui.Image image) {
    _cache[slide] = image;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first)?.dispose();
    }
  }

  StateError _disposedError(int slide) =>
      StateError('SlidePreviewService was disposed before slide $slide rendered.');

  void _pump() {
    while (!_disposed && _running < concurrency && _queue.isNotEmpty) {
      final next = _queue.removeFirst();
      _running++;
      unawaited(_render(next.slide, next.completer));
    }
  }

  Future<void> _render(int slide, Completer<ui.Image> completer) async {
    var landed = false;
    try {
      final image = await renderSlide(slide);
      // A service retired mid-render owns nothing any more: the image goes
      // straight to whoever awaited it, and is theirs to release.
      if (!_disposed) _store(slide, image);
      completer.complete(image);
      landed = true;
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    } finally {
      // remove() hands back the stored future; nothing awaits it here.
      unawaited(_inFlight.remove(slide));
      _running--;
      _pump();
    }
    // Outside the try: nothing a listener (or a disposed notifier) throws
    // may land on the completer a second time.
    if (landed) _notify();
  }
}

/// The preview service for the mounted presentation; the shell overrides it
/// with a renderer bound to its hidden preview stage.
final slidePreviewServiceProvider = Provider<SlidePreviewService>(
  (ref) => throw UnimplementedError(
    'slidePreviewServiceProvider must be overridden by the presenter shell '
    'with a renderer for the mounted deck.',
  ),
);
