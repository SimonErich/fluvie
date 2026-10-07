import 'dart:ui' show Offset, Rect;

import 'package:flutter/painting.dart' show BoxFit;
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show Arrow, Clip, Connector, Image, MediaSource, Shape, unknownSpecProps;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/render/shape_painter.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// Round-trips one element through the spec layer and returns the widget it
/// builds (annotations unwrap their scene-filling expand box).
Object _build(Map<String, Object?> json) {
  final spec = ElementSpec.fromJson(json, AnchorTable());
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  final built = spec.build(AnchorTable());
  return built is SizedBox ? built.child! : built;
}

Map<String, Object?> _doc(Map<String, Object?> element) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [element],
    },
  ],
};

void main() {
  group('Shape', () {
    test('line round-trips and builds', () {
      final widget =
          _build({
                'type': 'Shape',
                'kind': 'line',
                'from': {'x': 0, 'y': 0},
                'to': {'x': 100, 'y': 50},
                'color': '#FF0000',
                'strokeWidth': 4,
                'reveal': '12f',
              })
              as Shape;
      expect(widget.kind, ShapeKind.line);
      expect(widget.from, Offset.zero);
      expect(widget.to, const Offset(100, 50));
      expect(widget.strokeWidth, 4);
      expect(widget.reveal, const Time.frames(12));
    });

    test('rect, circle, and path build their geometry', () {
      final rect =
          _build({
                'type': 'Shape',
                'kind': 'rect',
                'rect': {'x': 10, 'y': 20, 'w': 100, 'h': 50},
              })
              as Shape;
      expect(rect.rect, const Rect.fromLTWH(10, 20, 100, 50));

      final circle =
          _build({
                'type': 'Shape',
                'kind': 'circle',
                'center': {'x': 160, 'y': 90},
                'radius': 40,
              })
              as Shape;
      expect(circle.center, const Offset(160, 90));
      expect(circle.radius, 40);

      final path = _build({'type': 'Shape', 'kind': 'path', 'path': 'M 0 0 L 100 0 Z'}) as Shape;
      expect(path.path, isNotNull);
      expect(path.path!.computeMetrics().single.length, closeTo(200, 1e-6));
    });

    test('a kind without its geometry is rejected', () {
      expect(
        () => _build({'type': 'Shape', 'kind': 'line'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({'type': 'Shape', 'kind': 'wiggle'}),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(() => _build({'type': 'Shape'}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('Arrow and Connector', () {
    test('Arrow round-trips and builds', () {
      final widget =
          _build({
                'type': 'Arrow',
                'from': {'x': 40, 'y': 200},
                'to': {'x': 160, 'y': 90},
                'headLength': 20,
                'strokeWidth': 2,
              })
              as Arrow;
      expect(widget.from, const Offset(40, 200));
      expect(widget.to, const Offset(160, 90));
      expect(widget.headLength, 20);
    });

    test('Connector round-trips, elbow included', () {
      final widget =
          _build({
                'type': 'Connector',
                'from': {'x': 60, 'y': 60},
                'to': {'x': 220, 'y': 160},
                'elbow': true,
              })
              as Connector;
      expect(widget.elbow, isTrue);
    });
  });

  group('Clip', () {
    test('round-trips source, trim, fit, volume, and poster', () {
      final widget =
          _build({
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': 'intro.mp4'},
                'trim': {'from': '2s', 'to': '7s'},
                'fit': 'cover',
                'volume': 0.6,
                'poster': {'kind': 'asset', 'value': 'poster.png'},
              })
              as Clip;
      expect(widget.source, const MediaSource.asset('intro.mp4'));
      expect(widget.trim!.start, const Time.seconds(2));
      expect(widget.trim!.end, const Time.seconds(7));
      expect(widget.fit, BoxFit.cover);
      expect(widget.audio.volume, 0.6);
      expect(widget.audio.muted, isFalse);
      expect(widget.poster, const MediaSource.asset('poster.png'));
    });

    test('volume zero mutes; network and file sources resolve', () {
      final muted =
          _build({
                'type': 'Clip',
                'source': {'kind': 'network', 'value': 'https://cdn.example.com/a.mp4'},
                'volume': 0,
              })
              as Clip;
      expect(muted.audio.muted, isTrue);
      expect(muted.source, MediaSource.network(Uri.parse('https://cdn.example.com/a.mp4')));

      final file =
          _build({
                'type': 'Clip',
                'source': {'kind': 'file', 'value': '/tmp/a.mp4'},
              })
              as Clip;
      expect(file.source, const MediaSource.file('/tmp/a.mp4'));
    });
  });

  group('Image completions', () {
    test('cornerRadius, crop, and frame round-trip and build', () {
      final widget =
          _build({
                'type': 'Image',
                'source': {'kind': 'asset', 'value': 'photo.png'},
                'fit': 'cover',
                'cornerRadius': 12,
                'crop': {'x': 0.1, 'y': 0.2, 'w': 0.5, 'h': 0.5},
                'frame': {'style': 'polaroid', 'caption': 'Summer'},
              })
              as Image;
      expect(widget.cornerRadius, 12);
      expect(widget.crop, const Rect.fromLTWH(0.1, 0.2, 0.5, 0.5));
      expect(widget.frame!.caption, 'Summer');
    });

    test('frame styles map to their factories; unknown styles are rejected', () {
      Image imageWith(Map<String, Object?> frame) =>
          _build({
                'type': 'Image',
                'source': {'kind': 'asset', 'value': 'p.png'},
                'frame': frame,
              })
              as Image;
      expect(imageWith({'style': 'rounded', 'radius': 20}).frame!.radius, 20);
      expect(imageWith({'style': 'card', 'elevation': 10}).frame!.elevation, 10);
      expect(imageWith({'style': 'none'}).frame, isNotNull);
      expect(() => imageWith({'style': 'baroque'}), throwsA(isA<FluvieSpecError>()));
    });
  });

  group('validation', () {
    test('a clean wave-1 document has no unknown props', () {
      final warnings = unknownSpecProps(
        _doc({
          'type': 'Clip',
          'source': {'kind': 'asset', 'value': 'a.mp4'},
          'trim': {'from': '0s', 'to': '1s'},
          'poster': {'kind': 'asset', 'value': 'p.png'},
        }),
      );
      expect(warnings, isEmpty);
    });

    test('typos inside the new nested objects are caught', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'trim': {'fromm': '0s'},
          }),
        ).single.toString(),
        contains('fromm'),
      );
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Shape',
            'kind': 'line',
            'from': {'x': 0, 'y': 0, 'z': 3},
            'to': {'x': 1, 'y': 1},
          }),
        ).single.toString(),
        contains('"z"'),
      );
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Image',
            'source': {'kind': 'asset', 'value': 'p.png'},
            'frame': {'style': 'card', 'shadow': 4},
          }),
        ).single.toString(),
        contains('shadow'),
      );
    });
  });
}
