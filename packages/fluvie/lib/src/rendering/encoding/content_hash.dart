import 'dart:convert';

import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/rendering/render_config.dart';

// The in-house FNV-1a-64 hash lives in `core/hash` so `core` value types can
// also key on it without inverting the layering. It is
// re-exported here to keep the established render-side import stable.
export 'package:fluvie/src/core/hash/fnv1a.dart' show fnv1a64Hex;

/// The fluvie version baked into every render digest (kept in lockstep with
/// `pubspec.yaml`); a version bump invalidates all cached frames.
const String fluvieRenderVersion = '0.1.0';

/// The digest that identifies one render's cached frames: a hash over the
/// full [config] JSON, the [compositionKey], and the [fluvieVersion].
///
/// Any change to any of the three produces a new digest, isolating cache
/// entries between configurations, compositions, and library versions. The
/// cache stays *advisory*: composition **code** changes under an
/// unchanged key are not detected — stale frames are evicted by version bumps
/// or a `--no-cache` run.
String renderDigest({
  required RenderConfig config,
  required String compositionKey,
  required String fluvieVersion,
}) => fnv1a64Hex(
  utf8.encode(
    jsonEncode({
      'config': config.toJson(),
      'compositionKey': compositionKey,
      'fluvieVersion': fluvieVersion,
    }),
  ),
);
