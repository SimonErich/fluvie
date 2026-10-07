import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';

/// A renderer whose every call parks until the test lands or fails it, so a
/// test decides exactly when a render finishes relative to a dispose.
final class _ControlledRenderer {
  final List<int> started = [];
  final Map<int, Completer<ui.Image>> _pending = {};

  Future<ui.Image> render(int slide) {
    started.add(slide);
    return (_pending[slide] = Completer<ui.Image>()).future;
  }

  Future<void> land(int slide) async {
    _pending.remove(slide)!.complete(await _pixel());
    await _settle();
  }

  Future<void> fail(int slide, Object error) async {
    _pending.remove(slide)!.completeError(error, StackTrace.current);
    await _settle();
  }
}

/// Lets every pending microtask and zero-duration timer run.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<ui.Image> _pixel() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF123456),
  );
  return recorder.endRecording().toImage(1, 1);
}

/// Runs [body] in its own error zone and returns the errors that escaped it.
///
/// The service drops the future of every render it starts, so a
/// double-completed completer surfaces here (and nowhere the caller can see
/// it) — exactly how the crash showed up on the real embedder.
Future<List<Object>> _errorsDuring(Future<void> Function() body) async {
  final errors = <Object>[];
  final done = Completer<void>();
  unawaited(
    runZonedGuarded(
      () async {
        try {
          await body();
          await _settle();
          done.complete();
        } on Object catch (error, stackTrace) {
          done.completeError(error, stackTrace);
        }
      },
      (error, _) => errors.add(error),
    ),
  );
  await done.future;
  return errors;
}

void main() {
  test('a render landing after dispose completes its caller exactly once', () async {
    final renderer = _ControlledRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    ui.Image? delivered;

    final errors = await _errorsDuring(() async {
      final pending = service.preview(0);
      await _settle();
      expect(renderer.started, [0]);
      service.dispose();
      await renderer.land(0);
      delivered = await pending.timeout(const Duration(seconds: 2));
    });

    expect(delivered, isNotNull, reason: 'the awaiting caller must not hang');
    expect(errors, isEmpty, reason: 'a disposed service must not complete a future twice');
  });

  test('a failing render surfaces its error to the caller exactly once', () async {
    final renderer = _ControlledRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    final outcomes = <Object>[];

    final errors = await _errorsDuring(() async {
      final pending = service.preview(0);
      unawaited(pending.then<void>(outcomes.add, onError: outcomes.add));
      await _settle();
      await renderer.fail(0, StateError('render blew up'));
    });

    expect(outcomes, hasLength(1));
    expect(outcomes.single, isA<StateError>());
    expect(errors, isEmpty);
  });

  test('dispose abandons queued renders without starting them', () async {
    final renderer = _ControlledRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render, concurrency: 1);
    Object? queuedOutcome;

    final errors = await _errorsDuring(() async {
      final first = service.preview(0);
      final queued = service.preview(1).then<Object?>((image) => image, onError: (Object e) => e);
      await _settle();
      expect(renderer.started, [0], reason: 'the concurrency cap holds slide 1 back');
      service.dispose();
      await renderer.land(0);
      expect(renderer.started, [0], reason: 'a disposed service starts no new render');
      queuedOutcome = await queued.timeout(const Duration(seconds: 2));
      await first.timeout(const Duration(seconds: 2));
    });

    expect(queuedOutcome, isA<StateError>(), reason: 'a queued caller must not hang');
    expect(errors, isEmpty);
  });

  test('preview after dispose fails fast instead of rendering', () async {
    final renderer = _ControlledRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    Object? outcome;

    final errors = await _errorsDuring(() async {
      service.dispose();
      outcome = await service
          .preview(0)
          .then<Object?>((image) => image, onError: (Object e) => e)
          .timeout(const Duration(seconds: 2));
    });

    expect(outcome, isA<StateError>());
    expect(renderer.started, isEmpty, reason: 'a disposed service renders nothing new');
    expect(errors, isEmpty);
  });

  test('a warm-up interrupted by dispose drops nothing on the zone', () async {
    final renderer = _ControlledRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render, concurrency: 1);

    final errors = await _errorsDuring(() async {
      final warming = service.pregenerateAll(4);
      await _settle();
      // The deck closes with slide 0 rendering and slides 1 to 3 queued.
      service.dispose();
      await renderer.land(0);
      await warming.timeout(const Duration(seconds: 2));
    });

    expect(errors, isEmpty, reason: 'best-effort warming reports nothing to the zone');
  });

  test('a render landing after dispose hands its image over intact', () async {
    final renderer = _ControlledRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    ui.Image? delivered;

    await _errorsDuring(() async {
      final pending = service.preview(0);
      await _settle();
      service.dispose();
      await renderer.land(0);
      delivered = await pending.timeout(const Duration(seconds: 2));
    });

    expect(
      delivered!.debugDisposed,
      isFalse,
      reason: 'a disposed service owns nothing, so the late image is the caller to keep',
    );
    delivered!.dispose();
  });
}
