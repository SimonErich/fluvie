part of 'audio_track_view.dart';

// Read actual built clips: effective transition windows and equal-power
// envelopes already live here, so program audition uses export timing.
List<AudioTrackView> _clipTrackViews(
  EditorDocument document,
  VideoTimebase timebase,
  Map<String, ClipMetadata> metadata,
) {
  final video = document.spec.build();
  final result = <AudioTrackView>[];
  void walk(Widget widget, TimeScopeData scope, int? scene, String? id) {
    final identity = widget is SpecElementId ? widget.id : id;
    if (widget is Clip && identity != null) {
      final raw = document.elementJson(identity);
      if (raw != null && raw['type'] == 'Clip') {
        final sourceJson = raw['source']! as Map<String, Object?>;
        final sourceKey = sourceJson['value']! as String;
        final authored = AudioTrackSpec.fromJson({
          'kind': 'music',
          'source': sourceJson,
          if (raw.containsKey('volume')) 'volume': raw['volume'],
          if (raw.containsKey('automation')) 'automation': raw['automation'],
          if (raw.containsKey('lane')) 'lane': raw['lane'],
        }, document.spec.anchors);
        var meta = metadata[sourceKey];
        if (meta == null) {
          for (final entry in document.mediaEntries) {
            if (entry.source['value'] == sourceKey &&
                entry.fps != null &&
                entry.durationFrames != null) {
              meta = (
                fps: entry.fps!,
                frameCount: entry.durationFrames!,
                width: entry.width ?? 1,
                height: entry.height ?? 1,
                hasAudio: true,
              );
              break;
            }
          }
        }
        final timeMap = widget.speedRamp == null
            ? null
            : AudioTimeMap(
                fps: timebase.fps,
                sourceSeconds: integrateClipSpeedRamp(
                  widget.speedRamp!,
                  fps: timebase.fps,
                  windowFrames: scope.durationFrames,
                ),
              );
        final unavailable = widget.trim != null && meta == null
            ? 'Load source metadata to audition this trimmed clip.'
            : null;
        final trim = unavailable == null
            ? resolveClipAudioTrimSeconds(
                trim: widget.trim,
                meta: meta,
                windowFrames: scope.durationFrames,
                fps: timebase.fps,
                sourceLabel: sourceKey,
                speed: timeMap == null
                    ? widget.speed
                    : timeMap.sourceSeconds.last / timeMap.durationSeconds,
              )
            : (start: 0.0, end: 0.0);
        final fadeIn = widget.audio.fadeIn.resolveFrames(scope) / timebase.fps;
        final fadeOut = widget.audio.fadeOut.resolveFrames(scope) / timebase.fps;
        final start = scope.startFrame / timebase.fps;
        final end = (scope.startFrame + scope.durationFrames) / timebase.fps;
        result.add(
          AudioTrackView(
            scene: scene,
            index: -1,
            elementId: identity,
            spec: authored,
            unavailableReason: unavailable,
            span: FrameSpan(scope.startFrame, scope.startFrame + scope.durationFrames),
            resolved: ResolvedAudioTrack(
              source: sourceKey,
              audioSource: clipAudioSourceFor(widget.source),
              delayMs: (start * 1000).round(),
              volume: widget.speed < 0 || unavailable != null || meta?.hasAudio == false
                  ? 0
                  : widget.audio.volume,
              volumeEnvelope: widget.audio.automation.resolve(
                fps: timebase.fps,
                windowFrames: scope.durationFrames,
              ),
              trimStartSeconds: trim.start,
              trimEndSeconds: trim.end,
              fadeInSeconds: fadeIn > 0 ? fadeIn : null,
              fadeOutSeconds: fadeOut > 0 ? fadeOut : null,
              fadeOutStartSeconds: math.max(start, end - fadeOut),
              endSeconds: end,
              tempo: widget.speed.abs(),
              timeMap: timeMap,
            ),
          ),
        );
      }
    }
    final below = widget is MotionTarget ? elementScopeFor(widget.window, scope) : scope;
    for (final child in declaredChildren(widget)) {
      walk(child, below, scene, identity);
    }
  }

  for (var i = 0; i < video.scenes.length; i++) {
    final span = timebase.sceneSpans[i];
    final scope = TimeScopeData(
      fps: timebase.fps,
      startFrame: span.start,
      durationFrames: span.durationFrames,
    );
    for (final child in video.scenes[i].children) {
      walk(child, scope, i, null);
    }
  }
  final scope = TimeScopeData(
    fps: timebase.fps,
    startFrame: 0,
    durationFrames: timebase.totalFrames,
  );
  for (final child in video.overlays) {
    walk(child, scope, null, null);
  }
  return result;
}
