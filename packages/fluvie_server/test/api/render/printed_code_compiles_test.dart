@Tags(['analysis'])
@Timeout(Duration(minutes: 5))
library;

// printVideoSpecJson is @experimental in fluvie_cli; this test pins its output.
// ignore_for_file: experimental_member_use
import 'dart:io';

import 'package:fluvie_cli/fluvie_cli.dart' show printVideoSpecJson;
import 'package:fluvie_validate/fluvie_validate.dart';
import 'package:test/test.dart';

/// The oracle for the spec→Dart printer: every printed snippet must analyze with
/// ZERO errors, warnings, or fluvie lints (info notes are dropped by the
/// analyzer). This catches the printer drifting from the public API, emitting an
/// undefined name, or producing a dangling anchor (a `Trigger.whenEnds` whose
/// `Anchor` is never declared).
///
/// It uses the same [FluvieCodeAnalyzer] root the server wires up
/// (`Directory.current`, which resolves `package:fluvie` via the workspace
/// package config), so a green run here means a green Playground validation for
/// the same spec.
void main() {
  // One analyzer is reused across fixtures; package resolution is the slow part.
  final analyzer = FluvieCodeAnalyzer(projectRoot: Directory.current);

  Future<void> expectClean(String name, Map<String, Object?> spec) async {
    final code = printVideoSpecJson(spec);
    final diagnostics = await analyzer.analyze(code);
    final blocking = diagnostics.where((d) => d.severity != FluvieDiagnosticSeverity.info).toList();
    expect(
      blocking,
      isEmpty,
      reason:
          '$name produced diagnostics:\n'
          '${blocking.map((d) => '  ${d.severity.name} ${d.code} @${d.line}:${d.column} ${d.message}').join('\n')}\n'
          '--- printed code ---\n$code',
    );
  }

  test('the kitchen-sink spec prints clean Dart', () async {
    await expectClean('kitchen-sink', _kitchenSink);
  });

  test('the anchored-triggers spec prints dangling-anchor-free Dart', () async {
    await expectClean('anchored-triggers', _anchoredTriggers);
  });

  test('the ambient-and-raw spec prints clean Dart', () async {
    await expectClean('ambient-and-raw', _ambientAndRaw);
  });
}

/// Multiple scenes; gradient and vhs backgrounds; Text+style, Box, Image.network,
/// Counter; fadeIn with the full timing tail (duration/ease/delay/stagger/repeat),
/// pop with a spring; mp4 export with quality; motionDefaults at video and scene
/// level; scene enter/exit transitions; the object form of alignment.
final Map<String, Object?> _kitchenSink = {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'poster': '0.5s',
  'export': {'mode': 'mp4', 'quality': 'high'},
  'motionDefaults': {'duration': '0.4s', 'ease': 'smooth'},
  'transition': {'kind': 'crossFade', 'duration': '0.3s'},
  'scenes': [
    {
      'duration': '3s',
      'background': {
        'kind': 'gradient',
        'colors': ['#FF101820', '#FF203040'],
        'begin': {'x': -1.0, 'y': -1.0},
        'end': 'bottomRight',
      },
      'enter': {'kind': 'wipe', 'duration': '0.4s', 'direction': 'right', 'overlap': true},
      'exit': {'kind': 'zoom', 'duration': '0.3s', 'into': 'center'},
      'motionDefaults': {'duration': '0.25s'},
      'children': [
        {
          'type': 'Text',
          'text': 'Hello, Fluvie',
          'style': {
            'color': '#FFFFFFFF',
            'fontSize': 72,
            'fontWeight': 'bold',
            'letterSpacing': 1.5,
            'height': 1.1,
          },
          'animate': [
            {
              'preset': 'fadeIn',
              'duration': '0.5s',
              'ease': 'out',
              'delay': '0.1s',
              'stagger': {'evenly': '0.6s'},
              'repeat': {'times': 2, 'yoyo': true, 'gap': '100ms'},
            },
          ],
        },
        {
          'type': 'Box',
          'color': '#FF00A0FF',
          'size': {'width': 200, 'height': 120},
          'animate': [
            {
              'preset': 'pop',
              'overshoot': 1.3,
              'spring': {'stiffness': 200, 'damping': 12, 'mass': 1, 'initialVelocity': 0},
            },
          ],
        },
      ],
    },
    {
      'duration': '2.5s',
      'background': {'kind': 'vhs'},
      'enter': {'kind': 'slide', 'duration': '0.4s', 'from': 'left'},
      'children': [
        {
          'type': 'Image',
          'source': {'kind': 'network', 'value': 'https://example.com/logo.png'},
          'fit': 'cover',
          'animate': [
            {'preset': 'slideIn', 'from': 'bottom', 'duration': '0.4s'},
          ],
        },
        {
          'type': 'Counter',
          'to': 1000,
          'from': 0,
          'reveal': '1.5s',
          'style': {'color': '#FFFFFF00', 'fontSize': 48},
        },
      ],
    },
  ],
};

/// An element `anchor` plus `Trigger.whenEnds`/`whenStarts` referencing it, and a
/// capped relative time `0.2r@0.8s` — exercises the shared-Anchor declarations so
/// the printed code is free of dangling anchors.
final Map<String, Object?> _anchoredTriggers = {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '4s',
      'background': {'kind': 'color', 'color': '#FF000000'},
      'children': [
        {
          'type': 'Text',
          'text': 'Title',
          'anchor': 'title',
          'animate': [
            {'preset': 'fadeIn', 'duration': '0.2r@0.8s'},
          ],
        },
        {
          'type': 'Text',
          'text': 'Subtitle',
          'animate': [
            {
              'preset': 'slideFadeIn',
              'from': 'left',
              'at': {'kind': 'whenEnds', 'anchor': 'title'},
            },
          ],
        },
        {
          'type': 'Text',
          'text': 'Tagline',
          'animate': [
            {
              'preset': 'fadeIn',
              'at': {'kind': 'whenStarts', 'anchor': 'title'},
            },
          ],
        },
      ],
    },
  ],
};

/// Ambient presets (grain, spin, drift, kenBurns) and a raw `fromTo` whose
/// keyframes carry color + origin, with an absolute trigger.
final Map<String, Object?> _ambientAndRaw = {
  'fluvieSpec': 1,
  'size': 'square',
  'fps': 30,
  'scenes': [
    {
      'duration': '3s',
      'children': [
        {
          'type': 'Box',
          'color': '#FF330033',
          'animate': [
            {'preset': 'grain', 'amount': 0.3},
            {'preset': 'spin', 'per': '2s'},
            {'preset': 'drift', 'to': 'right', 'distance': 0.2},
            {'preset': 'kenBurns', 'zoom': 1.2, 'pan': 'left'},
          ],
        },
        {
          'type': 'Text',
          'text': 'Raw',
          'animate': [
            {
              'from': {'scale': 0, 'color': '#FFFF0000', 'origin': 'topLeft'},
              'to': {'scale': 1, 'rotation': 0.5, 'color': '#FF00FF00', 'origin': 'center'},
              'duration': '0.6s',
              'ease': 'inOut',
              'at': {'kind': 'at', 'time': '0.5s'},
            },
          ],
        },
      ],
    },
  ],
};
