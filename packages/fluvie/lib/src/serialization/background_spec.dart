import 'package:flutter/painting.dart' show Alignment, BoxFit, Color;
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/serialization/codecs/alignment_codec.dart';
import 'package:fluvie/src/serialization/codecs/color_codec.dart';
import 'package:fluvie/src/serialization/codecs/enum_codec.dart';

/// The background variants the spec can build.
const Set<String> knownBackgroundKinds = {
  'color',
  'gradient',
  'radial',
  'image',
  'video',
  'noise',
  'vhs',
};

/// The data form of a [Background]: a `kind` plus that variant's properties.
///
/// [buildBackground] turns it into a real [Background] widget.
class BackgroundSpec {
  /// Creates a background spec of [kind] with the variant [props].
  BackgroundSpec({required this.kind, this.props = const {}});

  /// Reads a background spec from [json].
  ///
  /// Throws a [FluvieSpecError] (located at [path]) for a missing or unknown
  /// `kind`.
  factory BackgroundSpec.fromJson(Map<String, Object?> json, {List<String> path = const []}) {
    final kind = json['kind'];
    if (kind is! String) {
      throw FluvieSpecError('A background needs a "kind"', path: path);
    }
    if (!knownBackgroundKinds.contains(kind)) {
      throw FluvieSpecError('Unknown background "$kind"', path: path);
    }
    final props = <String, Object?>{
      for (final entry in json.entries)
        if (entry.key != 'kind') entry.key: entry.value,
    };
    return BackgroundSpec(kind: kind, props: props);
  }

  /// The background variant (`color`, `gradient`, ...).
  final String kind;

  /// The variant's properties, stored verbatim.
  final Map<String, Object?> props;

  /// The JSON form: the `kind` plus [props].
  Map<String, Object?> toJson() => {'kind': kind, ...props};

  /// Builds the real [Background] widget.
  Background build() => buildBackground(this);
}

/// Builds a real [Background] from a [BackgroundSpec].
Background buildBackground(BackgroundSpec spec) {
  final props = spec.props;
  switch (spec.kind) {
    case 'color':
      return Background.color(decodeColor(props['color'], path: const ['color']));
    case 'gradient':
      return Background.gradient(
        _colors(props['colors']),
        begin: _alignment(props['begin'], Alignment.topLeft),
        end: _alignment(props['end'], Alignment.bottomRight),
      );
    case 'radial':
      return Background.radial(_colors(props['colors']));
    case 'image':
      return Background.image(
        _string(props['source'], 'source'),
        fit: props['fit'] == null
            ? BoxFit.cover
            : decodeEnum(BoxFit.values, props['fit'], 'fit', path: const ['fit']),
      );
    case 'video':
      return Background.video(_string(props['source'], 'source'));
    case 'noise':
      return Background.noise(scale: _double(props['scale']) ?? 1);
    case 'vhs':
      return const Background.vhs();
  }
  // Defensive: fromJson validates the kind, so this is unreachable.
  throw FluvieSpecError('Unknown background "${spec.kind}"'); // coverage:ignore-line
}

List<Color> _colors(Object? raw) {
  if (raw is List) {
    return [
      for (var i = 0; i < raw.length; i++) decodeColor(raw[i], path: ['colors', '$i']),
    ];
  }
  throw FluvieSpecError('Expected a list of colors', path: const ['colors']);
}

Alignment _alignment(Object? raw, Alignment fallback) =>
    raw == null ? fallback : decodeAlignment(raw);

String _string(Object? raw, String field) {
  if (raw is String) return raw;
  throw FluvieSpecError('Expected a string "$field"', path: [field]);
}

double? _double(Object? raw) => raw is num ? raw.toDouble() : null;
