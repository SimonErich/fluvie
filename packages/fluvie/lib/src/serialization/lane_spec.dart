import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:meta/meta.dart';

/// What a lane holds, so a tool can group and colour its rows without
/// guessing from what happens to be on them.
enum LaneKind {
  /// Pictures: clips, titles, anything that paints.
  video,

  /// Sound.
  audio;

  /// The kind named [raw], or [video] when the document does not say.
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a name Fluvie does not
  /// know, rather than quietly filing it under video: a lane a tool cannot
  /// name is a lane it will draw in the wrong place.
  static LaneKind fromJson(Object? raw, {List<String> path = const []}) {
    if (raw == null) return LaneKind.video;
    for (final kind in LaneKind.values) {
      if (kind.name == raw) return kind;
    }
    throw FluvieSpecError(
      'Unknown lane kind "$raw". Expected one of: ${LaneKind.values.map((k) => k.name).join(', ')}',
      path: path,
    );
  }
}

/// One row of a timeline: a place to draw material, named so elements and
/// audio tracks can point at it.
///
/// A lane says which row a bar is drawn on. It does **not** define paint
/// order: z-order stays the `children` list, which four surfaces already take
/// as the single truth. Only [muted] reaches the render, because a mute the
/// export ignored would be a lie the author discovers in the file.
@immutable
final class LaneSpec {
  /// Declares a lane identified by [id].
  const LaneSpec({
    required this.id,
    this.name,
    this.kind = LaneKind.video,
    this.locked = false,
    this.muted = false,
    this.gain = 1,
    this.height,
  });

  /// Reads a lane from [json].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing id — a lane
  /// nothing can reference is a row with no purpose — or an unknown kind.
  factory LaneSpec.fromJson(Map<String, Object?> json, {List<String> path = const []}) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FluvieSpecError('A lane needs a non-empty "id" to be referenced by', path: path);
    }
    final height = json['height'];
    final gain = json['gain'];
    if (gain != null && (gain is! num || !gain.isFinite || gain < 0)) {
      throw FluvieSpecError(
        'Lane gain must be a finite non-negative number',
        path: [...path, 'gain'],
      );
    }
    return LaneSpec(
      id: id,
      name: json['name'] is String ? json['name']! as String : null,
      kind: LaneKind.fromJson(json['kind'], path: [...path, 'kind']),
      locked: json['locked'] == true,
      muted: json['muted'] == true,
      gain: (gain as num?)?.toDouble() ?? 1,
      height: height is num ? height.toDouble() : null,
    );
  }

  /// The keys a lane reads; the single source of truth for its
  /// unknown-property check.
  static const Set<String> knownKeys = {'id', 'name', 'kind', 'locked', 'muted', 'gain', 'height'};

  /// The lane's identity, referenced by an element or audio track's `lane`.
  final String id;

  /// What a tool calls this row, or null to let the tool name it.
  final String? name;

  /// What the lane holds.
  final LaneKind kind;

  /// Whether an editing tool treats the lane as locked. Editing policy, not
  /// render policy: Fluvie renders a locked lane exactly like any other.
  final bool locked;

  /// Whether the lane is silent. The one field here that reaches the render.
  final bool muted;

  /// Linear gain applied to every assigned audio track, without reordering.
  final double gain;

  /// How tall a tool draws the row, or null for its own default.
  final double? height;

  /// The JSON form, omitting everything left at its default so a plain lane
  /// stays a plain object.
  Map<String, Object?> toJson() => {
    'id': id,
    if (name != null) 'name': name,
    if (kind != LaneKind.video) 'kind': kind.name,
    if (locked) 'locked': true,
    if (muted) 'muted': true,
    if (gain != 1) 'gain': gain,
    if (height != null) 'height': height,
  };

  @override
  String toString() => 'LaneSpec($id, ${kind.name})';
}
