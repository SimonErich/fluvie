import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/quality.dart';
import 'package:fluvie/src/rendering/encoding/content_hash.dart';
import 'package:fluvie/src/rendering/render_config.dart';

void main() {
  group('fluvieRenderVersion', () {
    test('stays in lockstep with pubspec.yaml so a release invalidates the cache', () {
      // The constant is baked into every render digest; if it drifts behind the
      // package version, a bump stops invalidating cached frames (its dartdoc
      // promises otherwise). Read the version straight from the pubspec.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml has a version line');
      expect(fluvieRenderVersion, match!.group(1)!.trim());
    });
  });

  group('fnv1a64Hex', () {
    test('matches the known FNV-1a-64 vectors', () {
      // Reference vectors from the FNV specification (Fowler/Noll/Vo).
      expect(fnv1a64Hex(const []), 'cbf29ce484222325');
      expect(fnv1a64Hex(utf8.encode('a')), 'af63dc4c8601ec8c');
      expect(fnv1a64Hex(utf8.encode('foobar')), '85944171f73967e8');
    });

    test('is 16 lower-case hex characters (path-safe)', () {
      final hex = fnv1a64Hex(utf8.encode('fluvie'));
      expect(hex, matches(RegExp(r'^[0-9a-f]{16}$')));
    });
  });

  group('renderDigest', () {
    RenderConfig demo() => RenderConfig(width: 320, height: 240, frameCount: 48);

    String digestOf({RenderConfig? config, String key = 'demo', String version = '0.1.0'}) =>
        renderDigest(config: config ?? demo(), compositionKey: key, fluvieVersion: version);

    test('is stable across calls', () {
      expect(digestOf(), digestOf());
    });

    test('changes when any config field changes', () {
      final base = digestOf();
      expect(digestOf(config: demo().copyWith(width: 640)), isNot(base));
      expect(digestOf(config: demo().copyWith(height: 480)), isNot(base));
      expect(digestOf(config: demo().copyWith(fps: 24)), isNot(base));
      expect(digestOf(config: demo().copyWith(frameCount: 8)), isNot(base));
      expect(digestOf(config: demo().copyWith(startFrame: 1)), isNot(base));
      expect(digestOf(config: demo().copyWith(quality: Quality.low)), isNot(base));
      expect(digestOf(config: demo().copyWith(cacheEnabled: false)), isNot(base));
    });

    test('changes per composition key', () {
      expect(digestOf(key: 'other'), isNot(digestOf()));
    });

    test('changes per fluvie version', () {
      expect(digestOf(version: '0.2.0'), isNot(digestOf()));
    });
  });
}
