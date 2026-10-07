part of 'video_lane_model.dart';

extension _VideoLaneAudio on _VideoLaneBuilder {
  void _audioLane({required int? scene, required int index}) {
    final json = document.audioTracksJson(scene: scene)[index];
    final owner = scene == null ? FrameSpan(0, timebase.totalFrames) : timebase.sceneSpans[scene];
    final scope = OwnerFrameScope(timebase.fps, owner);
    final isSfx = json['kind'] == 'sfx';
    final trim = json['trim'];
    final trimFrom = trim is Map<String, Object?>
        ? decodeTime(trim['from']).resolveFrames(scope)
        : null;
    final trimTo = trim is Map<String, Object?>
        ? decodeTime(trim['to']).resolveFrames(scope)
        : null;
    final at = _atOf(json['at']);
    var start = owner.start;
    if (at == VideoAudioAt.time) {
      final time = (json['at']! as Map<String, Object?>)['time'];
      start = owner.start + decodeTime(time).resolveFrames(scope);
    }
    final int end;
    if (json['loop'] == true) {
      end = owner.end;
    } else if (isSfx) {
      end = start + timebase.fps;
    } else if (trimFrom != null && trimTo != null) {
      end = start + (trimTo - trimFrom);
    } else {
      end = owner.end;
    }
    final barId = scene == null ? 'audio:v:$index' : 'audio:s:$scene:$index';
    final span = FrameSpan(start, end.clamp(start, owner.end < start ? start : owner.end));
    _place(
      laneId: json['lane'] is String ? json['lane']! as String : null,
      ownRowId: 'audio-track:${barId.substring('audio:'.length)}',
      label: _audioLabel(json, scene),
      bar: TimelineBar(
        id: barId,
        start: span.start.toDouble(),
        end: span.end.toDouble(),
        color: isSfx ? palette.sfx : palette.music,
        badge: _audioBadge(json, isSfx, at),
      ),
    );
    audioBars[barId] = VideoAudioLaneBinding(
      scene: scene,
      index: index,
      isSfx: isSfx,
      span: span,
      at: at,
      trimFromFrames: trimFrom,
      trimToFrames: trimTo,
    );
  }

  VideoAudioAt _atOf(Object? at) {
    if (at == null) return VideoAudioAt.ownerStart;
    if (at is Map<String, Object?> && at['kind'] == 'at') return VideoAudioAt.time;
    return VideoAudioAt.trigger;
  }

  String _audioLabel(Map<String, Object?> json, int? scene) {
    final source = json['source']! as Map<String, Object?>;
    final value = source['value']! as String;
    final name = value.split('/').last;
    return scene == null ? name : '$name (slide ${scene + 1})';
  }

  String _audioBadge(Map<String, Object?> json, bool isSfx, VideoAudioAt at) {
    if (!isSfx) return 'music';
    if (at != VideoAudioAt.trigger) return 'sfx';
    final raw = json['at'];
    if (raw is String) return raw;
    return (raw! as Map<String, Object?>)['kind']! as String;
  }
}
