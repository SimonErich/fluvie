import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final Queue<void Function()> _queue = Queue();
  int _running = 0;

  /// The cached preview for [slide], or `null` when it has not rendered yet.
  /// Peeking refreshes the entry's recency.
  ui.Image? peek(int slide) {
    final image = _cache.remove(slide);
    if (image == null) return null;
    return _cache[slide] = image;
  }

  /// The preview for [slide]: served from the cache, joined onto an
  /// in-flight render, or queued behind the concurrency cap.
  Future<ui.Image> preview(int slide) {
    final cached = peek(slide);
    if (cached != null) return Future.value(cached);
    final pending = _inFlight[slide];
    if (pending != null) return pending;
    final completer = Completer<ui.Image>();
    _inFlight[slide] = completer.future;
    _queue.add(() => _render(slide, completer));
    _pump();
    return completer.future;
  }

  /// Warms the cache for every slide of a [slideCount]-slide deck, in order.
  Future<void> pregenerateAll(int slideCount) =>
      Future.wait([for (var s = 0; s < slideCount; s++) preview(s)]);

  /// Drops every cached preview (and their recency) so content changes
  /// re-render. In-flight renders still land.
  void invalidate() {
    _cache.clear();
    notifyListeners();
  }

  void _pump() {
    while (_running < concurrency && _queue.isNotEmpty) {
      _running++;
      _queue.removeFirst()();
    }
  }

  Future<void> _render(int slide, Completer<ui.Image> completer) async {
    try {
      final image = await renderSlide(slide);
      _cache[slide] = image;
      while (_cache.length > capacity) {
        _cache.remove(_cache.keys.first);
      }
      completer.complete(image);
      notifyListeners();
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      // remove() hands back the stored future; nothing awaits it here.
      unawaited(_inFlight.remove(slide));
      _running--;
      _pump();
    }
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
