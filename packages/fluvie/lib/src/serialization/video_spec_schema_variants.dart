import 'package:flutter/painting.dart' show BoxFit;
import 'package:fluvie/src/serialization/background_spec.dart'
    show knownBackgroundKinds, knownBackgroundProps;
import 'package:fluvie/src/serialization/element_spec.dart'
    show knownElementProps, knownElementTypes;

/// The `BoxFit` names a `fit` field accepts, derived from the enum so the schema
/// cannot drift from the codec.
final List<String> _boxFitNames = [for (final fit in BoxFit.values) fit.name];

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
  'Text': {'text'},
  'Box': {},
  'Image': {'source'},
  'Counter': {'to'},
};

Map<String, Object?> _elementDef(String type) => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['type', ..._requiredElementProps[type] ?? const <String>{}],
  'properties': {
    'type': {'const': type},
    'anchor': {'type': 'string'},
    'animate': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/animation'},
    },
    for (final prop in knownElementProps[type] ?? const <String>{}) prop: _elementPropSchema(prop),
  },
};

Object _elementPropSchema(String prop) => switch (prop) {
  'text' => {'type': 'string'},
  'style' => {r'$ref': r'#/$defs/textStyle'},
  'color' => {r'$ref': r'#/$defs/color'},
  'size' => {r'$ref': r'#/$defs/size'},
  'source' => {r'$ref': r'#/$defs/imageSource'},
  'fit' => {'type': 'string', 'enum': _boxFitNames},
  'to' => {'type': 'number'},
  'from' => {'type': 'number'},
  'duration' => {r'$ref': r'#/$defs/time'},
  _ => const <String, Object?>{},
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
  'begin' => {r'$ref': r'#/$defs/alignment'},
  'end' => {r'$ref': r'#/$defs/alignment'},
  'source' => {'type': 'string'},
  'fit' => {'type': 'string', 'enum': _boxFitNames},
  'scale' => {'type': 'number'},
  _ => const <String, Object?>{},
};
