part of 'audio_track_section.dart';

/// The section's field rows over one track's raw JSON: reads resolve
/// authored times to frames through the owner scope, writes are canonical
/// frames-form patches with constructor defaults elided.
final class _AudioFields {
  _AudioFields({required this.json, required this.scope, required this.patch});

  final Map<String, Object?> json;
  final OwnerFrameScope scope;
  final void Function(Map<String, Object?> patch) patch;

  bool get _isSfx => json['kind'] == 'sfx';

  Map<String, Object?>? get _trim =>
      json['trim'] is Map<String, Object?> ? json['trim']! as Map<String, Object?> : null;

  /// The sfx `at` when it is placeable in time: absent or the `at`-kind
  /// trigger. A non-time trigger reads as null (see [triggerNote]).
  int? get _startFrames {
    final at = json['at'];
    if (at == null) return 0;
    if (at is Map<String, Object?> && at['kind'] == 'at') {
      return decodeTime(at['time']).resolveFrames(scope);
    }
    return null;
  }

  /// The honest line shown instead of a start field when a trigger places
  /// the effect.
  String? get triggerNote {
    if (!_isSfx || _startFrames != null) return null;
    final at = json['at'];
    final kind = at is String ? at : (at! as Map<String, Object?>)['kind']! as String;
    return 'Fires on $kind';
  }

  int _frames(Object? raw) => raw == null ? 0 : decodeTime(raw).resolveFrames(scope);

  String? _framesJson(int frames) => frames <= 0 ? null : '${frames}f';

  List<OiPropertyRow> rows() {
    final volume = json['volume'];
    final trim = _trim;
    final start = _startFrames;
    return [
      OiPropertyRow(
        label: 'Volume',
        editor: MathNumberInput(
          key: const ValueKey('audio-volume'),
          label: '',
          value: volume is num ? volume.toDouble() : 1,
          min: 0,
          step: 0.1,
          decimals: 2,
          onChanged: (next) => patch({'volume': next == 1 ? null : next}),
        ),
      ),
      if (!_isSfx) ...[
        OiPropertyRow(
          label: 'Fade in',
          editor: _framesField('audio-fade-in', json['fadeIn'], 'fadeIn'),
        ),
        OiPropertyRow(
          label: 'Fade out',
          editor: _framesField('audio-fade-out', json['fadeOut'], 'fadeOut'),
        ),
        OiPropertyRow(
          label: 'Loop',
          editor: OiSwitch(
            value: json['loop'] == true,
            onChanged: (next) => patch({'loop': next ? true : null}),
          ),
        ),
        if (trim != null) ...[
          OiPropertyRow(
            label: 'Trim from',
            editor: MathNumberInput(
              key: const ValueKey('audio-trim-from'),
              label: '',
              value: _frames(trim['from']).toDouble(),
              min: 0,
              max: (_frames(trim['to']) - 1).toDouble(),
              decimals: 0,
              onChanged: (next) => patch({
                'trim': {'from': '${next.round()}f', 'to': '${_frames(trim['to'])}f'},
              }),
            ),
          ),
          OiPropertyRow(
            label: 'Trim to',
            editor: MathNumberInput(
              key: const ValueKey('audio-trim-to'),
              label: '',
              value: _frames(trim['to']).toDouble(),
              min: (_frames(trim['from']) + 1).toDouble(),
              decimals: 0,
              onChanged: (next) => patch({
                'trim': {'from': '${_frames(trim['from'])}f', 'to': '${next.round()}f'},
              }),
            ),
          ),
        ],
      ],
      if (_isSfx && start != null)
        OiPropertyRow(
          label: 'Start',
          editor: MathNumberInput(
            key: const ValueKey('audio-start'),
            label: '',
            value: start.toDouble(),
            min: 0,
            decimals: 0,
            onChanged: (next) => patch({
              'at': {'kind': 'at', 'time': '${next.round()}f'},
            }),
          ),
        ),
    ];
  }

  Widget _framesField(String key, Object? raw, String jsonKey) => MathNumberInput(
    key: ValueKey(key),
    label: '',
    value: _frames(raw).toDouble(),
    min: 0,
    decimals: 0,
    onChanged: (next) => patch({jsonKey: _framesJson(next.round())}),
  );
}
