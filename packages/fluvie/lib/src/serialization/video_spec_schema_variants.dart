import 'package:flutter/painting.dart' show BoxFit, TextAlign;
import 'package:fluvie/src/core/audio_band.dart' show AudioBand;
import 'package:fluvie/src/serialization/background_spec.dart'
    show knownBackgroundKinds, knownBackgroundProps;
import 'package:fluvie/src/serialization/effect_spec.dart';
import 'package:fluvie/src/serialization/element_spec.dart'
    show knownElementProps, knownElementTypes;

part 'video_spec_schema_element_props.dart';
part 'video_spec_schema_effect_variants.dart';

/// The per-type element `oneOf` for the schema's `element` def: one closed
/// (`additionalProperties: false`) variant per element type, listing exactly the
/// fields `buildElement` reads for that `type`.
List<Object?> elementVariants() => [for (final type in knownElementTypes) _elementDef(type)];

/// The per-kind background `oneOf` for the schema's `background` def, closed over
/// exactly the fields `buildBackground` reads for each `kind`.
List<Object?> backgroundVariants() => [
  for (final kind in knownBackgroundKinds) _backgroundDef(kind),
];

/// The content props each element type requires, mirrored by the parser.
const Map<String, Set<String>> _requiredElementProps = {
  // A Text takes exactly one of `text` or `spans`; the parser enforces the
  // exclusivity (like Chart's data shapes), so neither is schema-required.
  'Text': {},
  'SplitText': {'text'},
  'Box': {},
  'Image': {'source'},
  'Counter': {'to'},
  'Shape': {'kind'},
  'Arrow': {'from', 'to'},
  'Connector': {'from', 'to'},
  'Clip': {'source'},
  'Typewriter': {'text'},
  'Markdown': {'source'},
  'Terminal': {'lines'},
  'Code': {'source'},
  'Chart': {'variant'},
  'Mermaid': {'source'},
  'WebView': {'uri', 'viewport'},
  'Html': {'source', 'viewport'},
  'Bars': {},
  'LowerThird': {'name'},
  'TitleCard': {'title'},
  'Snapshot': {'child'},
  'DeviceFrame': {'variant', 'child'},
  'Callout': {'label', 'target', 'child'},
  'Spotlight': {'region', 'child'},
  // A Group's children list is required but may be empty (an empty group
  // renders nothing).
  'Group': {'children'},
};

/// Every element variant with `shared` removed: the overlay form.
///
/// An overlay already runs the whole video, so there is no boundary for it to
/// morph across, and the parser refuses one that names a hero. A schema that
/// still advertised the key would tell a constrained-decoding model the field
/// is legal and then reject what it emitted.
List<Object?> overlayElementVariants() => [
  for (final type in knownElementTypes) _elementDef(type, shared: false),
];

Map<String, Object?> _elementDef(String type, {bool shared = true}) => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['type', ..._requiredElementProps[type] ?? const <String>{}],
  'properties': {
    'type': {'const': type},
    'id': {'type': 'string'},
    'transform': {r'$ref': r'#/$defs/transform'},
    'anchor': {'type': 'string'},
    if (shared) 'shared': {'type': 'string'},
    'visible': {'type': 'boolean'},
    'show': {r'$ref': r'#/$defs/show'},
    'lane': {r'$ref': r'#/$defs/laneRef'},
    'effects': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/effect'},
    },
    'animate': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/animation'},
    },
    for (final prop in knownElementProps[type] ?? const <String>{})
      prop: _elementPropSchema(type, prop),
  },
};

/// The props each background kind requires, mirrored by the parser.
const Map<String, Set<String>> _requiredBackgroundProps = {
  'color': {'color'},
  'gradient': {'colors'},
  'radial': {'colors'},
  'image': {'source'},
  'video': {'source'},
  'noise': {},
  'vhs': {},
};

Map<String, Object?> _backgroundDef(String kind) => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['kind', ..._requiredBackgroundProps[kind] ?? const <String>{}],
  'properties': {
    'kind': {'const': kind},
    for (final prop in knownBackgroundProps[kind] ?? const <String>{})
      prop: _backgroundPropSchema(prop),
  },
};

Object _backgroundPropSchema(String prop) => switch (prop) {
  'color' => {r'$ref': r'#/$defs/color'},
  'colors' => {
    'type': 'array',
    'items': {r'$ref': r'#/$defs/color'},
  },
  'stops' => {
    'type': 'array',
    'items': {'type': 'number', 'minimum': 0, 'maximum': 1},
  },
  'begin' => {r'$ref': r'#/$defs/alignment'},
  'end' => {r'$ref': r'#/$defs/alignment'},
  'source' => {'type': 'string'},
  'fit' => {'type': 'string', 'enum': _boxFitNames},
  'scale' => {'type': 'number'},
  _ => const <String, Object?>{},
};
