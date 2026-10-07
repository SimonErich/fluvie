part of 'video_spec.dart';

/// The root data form of a video: the serializable document an LLM emits and
/// Fluvie deserializes into a real [Video] to render deterministically.
///
/// Read one with [VideoSpec.fromJson], render it with [build], and persist it
/// with [toJson]. The [anchors] table is the single source of anchor identity
/// for the whole document, so triggers that reference an anchor and the element
/// that declares it resolve to the same `Anchor` instance (see [AnchorTable]) —
/// which is why [build] reuses the table [VideoSpec.fromJson] created.
final class VideoSpec {
  /// Creates a video spec from its [scenes] and composition-wide settings.
  ///
  /// [anchors] is the identity table; [VideoSpec.fromJson] supplies the one it
  /// built so triggers and element anchors stay consistent. A hand-built spec
  /// gets a fresh table by default.
  VideoSpec({
    required this.scenes,
    this.size = VideoSize.reels,
    this.fps = VideoDefaults.fps,
    this.poster,
    this.export,
    this.motionDefaults,
    this.transition,
    this.theme,
    this.masters = const {},
    this.audio = const [],
    this.lanes = const [],
    this.overlays = const [],
    this.editorData,
    AnchorTable? anchors,
  }) : anchors = anchors ?? AnchorTable();

  /// Reads a video spec from a decoded JSON [json] document.
  ///
  /// Throws a [FluvieSpecError] for an unsupported [schemaVersion], a
  /// missing/empty `scenes` list, or a scene adopting an unknown master or
  /// filling an unknown slot, naming where the problem is.
  factory VideoSpec.fromJson(Map<String, Object?> json) => _parseVideoSpec(json);

  /// The schema version this build reads and writes.
  static const int schemaVersion = 1;

  /// The top-level keys a [VideoSpec] document reads. The single source of truth
  /// for the document-root unknown-property check; it must stay in step with the
  /// keys [VideoSpec.fromJson] consumes.
  static const Set<String> knownKeys = {
    'fluvieSpec',
    'size',
    'fps',
    'poster',
    'export',
    'motionDefaults',
    'transition',
    'theme',
    'masters',
    'audio',
    'lanes',
    'overlays',
    'scenes',
    'editor',
  };

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

  /// The deck theme the document's `{"token": ...}` references resolve
  /// against in [build], or null for none. It counts into [digest], so a
  /// theme change re-renders everything bound to a token.
  final ThemeSpec? theme;

  /// The named master layouts scenes adopt through their `master` key,
  /// applied at build time by [resolveSceneMaster] — no copies, so editing
  /// a master changes every adopting scene. They count into [digest].
  final Map<String, MasterSpec> masters;

  /// The composition-wide audio tracks, video-first in the mix order; empty
  /// for a silent deck. Engine-consumed: [build] hands them to `Video.audio`,
  /// so the audio collector and the amix plan read them unchanged, and they
  /// count into [digest].
  final List<AudioTrackSpec> audio;

  /// The anchor identity table shared across this document (see class docs).
  final AnchorTable anchors;

  /// The elements that live outside every scene, on the whole video's clock.
  ///
  /// One instance for the whole video, which is what a scene-paired morph can
  /// never be: an overlay's `show` window resolves against the video's own
  /// length rather than a scene's, so it crosses every boundary without ever
  /// re-mounting. Which slide an editor draws it on is editorial, so it lives
  /// in the `editor` block and never moves the digest.
  final List<ElementSpec> overlays;

  /// The timeline rows this document declares, in the order a tool draws
  /// them. Empty in a document that never mentions one.
  ///
  /// Presentational, with one exception: a muted lane's audio is dropped from
  /// [build], because a mute the export ignored would be a lie the author
  /// only discovers in the file. Everything else here says where material is
  /// *shown* and nothing about what order it paints in.
  final List<LaneSpec> lanes;

  /// The editing tool's own block, preserved verbatim and never interpreted:
  /// names, locks, guides, and whatever else an editor keeps. It is excluded
  /// from [digest], so annotating a document never invalidates render caches.
  final Map<String, Object?>? editorData;

  /// The JSON form, including the [schemaVersion] marker. Re-parsing this form
  /// is stable (the serialization is canonical).
  Map<String, Object?> toJson() => _encodeVideoSpec(this);

  /// The video-level animation defaults with the theme's [ThemeSpec.motion]
  /// composed *under* the explicit [motionDefaults]: an explicitly set field
  /// wins, an unset one falls through to the theme; the rest of the cascade
  /// (scene, animation-local) is untouched.
  Defaults? get effectiveMotionDefaults => switch (theme?.motion) {
    null => motionDefaults,
    final themed => motionDefaults?.mergeOver(themed) ?? themed,
  };

  /// Builds the real [Video] widget, reusing [anchors] so timing references
  /// resolve to consistent anchor instances. The build runs inside
  /// [ThemeSpec.resolve], so token references resolve or fail loudly, and
  /// every scene resolves its adopted master first ([resolveSceneMaster]).
  Video build() => _buildVideoSpec(this);

  /// The ids of the lanes this document silences.
  ///
  /// Public because more than one builder turns a spec into a `Video`, and a
  /// mute honoured by one and ignored by the other is a deck that sounds
  /// different depending on who mounted it.
  Set<String> get mutedLaneIds => {
    for (final lane in lanes)
      if (lane.muted) lane.id,
  };

  /// The audio tracks this spec actually plays: every declared track that is
  /// not on a muted lane.
  /// Linear mix gain by lane id; no declaration-order changes.
  Map<String, double> get laneGains => {for (final lane in lanes) lane.id: lane.gain};

  /// Builds unmuted tracks in their original declaration order.
  List<Audio> buildAudio() => [
    for (final track in audio)
      if (!mutedLaneIds.contains(track.lane)) track.build(laneGain: laneGains[track.lane] ?? 1),
  ];

  /// The overlay widgets this spec mounts outside every scene.
  List<Widget> buildOverlays() => [
    for (final overlay in overlays)
      applyClipLaneMix(
        overlay,
        anchors,
        mutedLaneIds: mutedLaneIds,
        laneGains: laneGains,
      ).build(anchors),
  ];

  /// A stable content digest of this spec — a hash over its canonical JSON
  /// with the `editor` block stripped, so only render-affecting content
  /// moves it.
  ///
  /// Identical specs produce identical digests, so an AI-authored video keys
  /// the frame cache and identifies its output reproducibly, and an editor
  /// annotating a document never invalidates those caches.
  String digest() {
    final json = toJson()..remove('editor');
    return fnv1a64Hex(utf8.encode(jsonEncode(json)));
  }
}
