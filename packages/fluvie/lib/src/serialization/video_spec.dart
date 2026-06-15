import 'dart:convert';

import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/codecs/defaults_codec.dart';
import 'package:fluvie/src/serialization/codecs/export_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';
import 'package:fluvie/src/serialization/codecs/video_size_codec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';

/// The root data form of a video: the serializable document an LLM emits and
/// Fluvie deserializes into a real [Video] to render deterministically.
///
/// Read one with [VideoSpec.fromJson], render it with [build], and persist it
/// with [toJson]. The [anchors] table is the single source of anchor identity
/// for the whole document, so triggers that reference an anchor and the element
/// that declares it resolve to the same `Anchor` instance (see [AnchorTable]) —
/// which is why [build] reuses the table [VideoSpec.fromJson] created.
class VideoSpec {
  /// Creates a video spec from its [scenes] and composition-wide settings.
  ///
  /// [anchors] is the identity table; [VideoSpec.fromJson] supplies the one it
  /// built so triggers and element anchors stay consistent. A hand-built spec
  /// gets a fresh table by default.
  VideoSpec({
    required this.scenes,
    this.size = VideoSize.reels,
    this.fps = 30,
    this.poster,
    this.export,
    this.motionDefaults,
    this.transition,
    AnchorTable? anchors,
  }) : anchors = anchors ?? AnchorTable();

  /// Reads a video spec from a decoded JSON [json] document.
  ///
  /// Throws a [FluvieSpecError] for an unsupported [schemaVersion] or a
  /// missing/empty `scenes` list, naming where the problem is.
  factory VideoSpec.fromJson(Map<String, Object?> json) {
    final version = json['fluvieSpec'];
    if (version != null && version != schemaVersion) {
      throw FluvieSpecError(
        'Unsupported fluvieSpec version $version; this build reads version $schemaVersion',
      );
    }
    final scenesRaw = json['scenes'];
    if (scenesRaw is! List || scenesRaw.isEmpty) {
      throw FluvieSpecError('A video needs a non-empty "scenes" list', path: const ['scenes']);
    }
    final anchors = AnchorTable();
    final scenes = <SceneSpec>[];
    for (var i = 0; i < scenesRaw.length; i++) {
      final scene = scenesRaw[i];
      if (scene is! Map<String, Object?>) {
        throw FluvieSpecError('Expected a scene object', path: ['scenes', '$i']);
      }
      scenes.add(SceneSpec.fromJson(scene, anchors, path: ['scenes', '$i']));
    }
    final size = json['size'];
    final fps = json['fps'];
    final poster = json['poster'];
    final export = json['export'];
    final motion = json['motionDefaults'];
    final transition = json['transition'];
    return VideoSpec(
      scenes: scenes,
      anchors: anchors,
      size: size == null ? VideoSize.reels : decodeVideoSize(size, path: const ['size']),
      fps: fps is int ? fps : 30,
      poster: poster == null ? null : decodeTime(poster, path: const ['poster']),
      export: export == null ? null : decodeExport(export, path: const ['export']),
      motionDefaults: motion == null
          ? null
          : decodeDefaults(motion, path: const ['motionDefaults']),
      transition: transition == null
          ? null
          : decodeTransition(transition, path: const ['transition']),
    );
  }

  /// The schema version this build reads and writes.
  static const int schemaVersion = 1;

  /// The scenes, played back-to-back. Never empty.
  final List<SceneSpec> scenes;

  /// The canvas size.
  final VideoSize size;

  /// Frames per second.
  final int fps;

  /// The poster frame time, or null for frame zero.
  final Time? poster;

  /// The export configuration, or null for the render default.
  final Export? export;

  /// Video-level animation defaults, or null to inherit the package defaults.
  final Defaults? motionDefaults;

  /// The default scene-to-scene transition, or null for hard cuts.
  final Transition? transition;

  /// The anchor identity table shared across this document (see class docs).
  final AnchorTable anchors;

  /// The JSON form, including the [schemaVersion] marker. Re-parsing this form
  /// is stable (the serialization is canonical).
  Map<String, Object?> toJson() => {
    'fluvieSpec': schemaVersion,
    'size': encodeVideoSize(size),
    'fps': fps,
    if (poster != null) 'poster': encodeTime(poster!),
    if (export != null) 'export': encodeExport(export!),
    if (motionDefaults != null) 'motionDefaults': encodeDefaults(motionDefaults!),
    if (transition != null) 'transition': encodeTransition(transition!),
    'scenes': [for (final scene in scenes) scene.toJson()],
  };

  /// Builds the real [Video] widget, reusing [anchors] so timing references
  /// resolve to consistent anchor instances.
  Video build() => Video(
    size: size,
    fps: fps,
    poster: poster,
    export: export,
    motionDefaults: motionDefaults,
    transition: transition,
    scenes: [for (final scene in scenes) scene.build(anchors)],
  );

  /// A stable content digest of this spec — a hash over its canonical JSON.
  ///
  /// Identical specs produce identical digests, so an AI-authored video keys
  /// the frame cache and identifies its output reproducibly.
  String digest() => fnv1a64Hex(utf8.encode(jsonEncode(toJson())));
}

/// Builds a real [Video] from [spec] — a free-function alias for
/// [VideoSpec.build] that reads naturally at call sites.
Video buildVideo(VideoSpec spec) => spec.build();
