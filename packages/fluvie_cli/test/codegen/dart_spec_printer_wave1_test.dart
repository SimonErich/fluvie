import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

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

Map<String, Object?> _animated(Map<String, Object?> animation) => _doc({
  'type': 'Box',
  'color': '#6C5CE7',
  'animate': [animation],
});

void main() {
  group('wave-1 elements print their constructors', () {
    test('Shape kinds', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Shape',
            'kind': 'line',
            'from': {'x': 0, 'y': 0},
            'to': {'x': 100, 'y': 50},
            'color': '#FF0000',
            'strokeWidth': 4,
            'reveal': '12f',
          }),
        ),
        allOf(
          contains('Shape.line('),
          contains('from: Offset(0, 0)'),
          contains('to: Offset(100, 50)'),
          contains('strokeWidth: 4'),
          contains('reveal: 12.frames'),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Shape',
            'kind': 'rect',
            'rect': {'x': 1, 'y': 2, 'w': 3, 'h': 4},
          }),
        ),
        contains('Shape.rect(rect: Rect.fromLTWH(1, 2, 3, 4))'),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Shape',
            'kind': 'circle',
            'center': {'x': 160, 'y': 90},
            'radius': 40,
          }),
        ),
        allOf(contains('Shape.circle('), contains('radius: 40')),
      );
      expect(
        printVideoSpecJson(_doc({'type': 'Shape', 'kind': 'path', 'path': 'M 0 0 L 1 1'})),
        contains("Shape.path(path: pathFromSvg('M 0 0 L 1 1'))"),
      );
      expect(
        () => printVideoSpecJson(_doc({'type': 'Shape', 'kind': 'wiggle'})),
        throwsFormatException,
      );
    });

    test('Arrow and Connector', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Arrow',
            'from': {'x': 1, 'y': 2},
            'to': {'x': 3, 'y': 4},
            'headLength': 20,
          }),
        ),
        allOf(contains('Arrow.to('), contains('headLength: 20')),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Connector',
            'from': {'x': 1, 'y': 2},
            'to': {'x': 3, 'y': 4},
            'elbow': true,
          }),
        ),
        allOf(contains('Connector('), contains('elbow: true')),
      );
    });

    test('Clip fadeOut prints alongside fadeIn in the audio policy', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'fadeIn': '6f',
            'fadeOut': '12f',
          }),
        ),
        contains('audio: ClipAudio.included(fadeIn: 6.frames, fadeOut: 12.frames)'),
      );
    });

    test('a fadeOut alone still prints an audio policy', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'fadeOut': '12f',
          }),
        ),
        contains('audio: ClipAudio.included(fadeOut: 12.frames)'),
      );
    });

    test('Clip speed prints as the rate, and source speed prints nothing', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'speed': 0.5,
          }),
        ),
        contains('speed: 0.5'),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
          }),
        ),
        isNot(contains('speed:')),
        reason: 'an omitted rate stays omitted, so printed code reads as authored',
      );
    });

    test('a reversed Clip prints its negative rate', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'speed': -1,
          }),
        ),
        contains('speed: -1'),
      );
    });

    test('Clip sources, audio policy, and poster', () {
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'trim': {'from': '2s', 'to': '7s'},
            'fit': 'cover',
            'volume': 0.5,
            'poster': {'kind': 'network', 'value': 'https://cdn.example.com/p.png'},
          }),
        ),
        allOf(
          contains('Clip.asset('),
          contains("'a.mp4'"),
          contains('trim: TimeRange(2.seconds, 7.seconds)'),
          contains('fit: BoxFit.cover'),
          contains('audio: ClipAudio.included(volume: 0.5)'),
          contains("poster: MediaSource.network(Uri.parse('https://cdn.example.com/p.png'))"),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'network', 'value': 'https://cdn.example.com/a.mp4'},
            'volume': 0,
          }),
        ),
        allOf(
          contains("Clip.network(Uri.parse('https://cdn.example.com/a.mp4')"),
          contains('audio: ClipAudio.muted()'),
        ),
      );
      expect(
        printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'file', 'value': '/tmp/a.mp4'},
            'poster': {'kind': 'file', 'value': '/tmp/p.png'},
          }),
        ),
        allOf(
          contains("Clip.file('/tmp/a.mp4'"),
          contains("poster: MediaSource.file('/tmp/p.png')"),
        ),
      );
      expect(
        () => printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'carrier-pigeon', 'value': 'a.mp4'},
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => printVideoSpecJson(
          _doc({
            'type': 'Clip',
            'source': {'kind': 'asset', 'value': 'a.mp4'},
            'poster': {'kind': 'pigeon', 'value': 'p'},
          }),
        ),
        throwsFormatException,
      );
    });

    test('Image completions and every frame style', () {
      String imageWith(Map<String, Object?> extras) => printVideoSpecJson(
        _doc({
          'type': 'Image',
          'source': {'kind': 'asset', 'value': 'p.png'},
          ...extras,
        }),
      );
      expect(
        imageWith({
          'cornerRadius': 12,
          'crop': {'x': 0.1, 'y': 0.2, 'w': 0.5, 'h': 0.5},
        }),
        allOf(contains('cornerRadius: 12'), contains('crop: Rect.fromLTWH(0.1, 0.2, 0.5, 0.5)')),
      );
      expect(
        imageWith({
          'frame': {'style': 'none'},
        }),
        contains('frame: PhotoFrame.none()'),
      );
      expect(
        imageWith({
          'frame': {'style': 'rounded', 'radius': 20},
        }),
        contains('frame: PhotoFrame.rounded(radius: 20)'),
      );
      expect(
        imageWith({
          'frame': {'style': 'card', 'radius': 16, 'elevation': 10},
        }),
        contains('frame: PhotoFrame.card(radius: 16, elevation: 10)'),
      );
      expect(
        imageWith({
          'frame': {'style': 'polaroid', 'caption': 'Summer'},
        }),
        contains("frame: PhotoFrame.polaroid(caption: 'Summer')"),
      );
      expect(
        () => imageWith({
          'frame': {'style': 'baroque'},
        }),
        throwsFormatException,
      );
    });
  });

  group('wave-1 presets print their calls', () {
    test('mask wipes, glitches, float, and pulse', () {
      expect(
        printVideoSpecJson(
          _animated({'preset': 'maskWipeIn', 'shape': 'diagonal', 'origin': 'topLeft'}),
        ),
        allOf(
          contains('Animation.maskWipeIn('),
          contains('shape: WipeShape.diagonal'),
          contains('origin: Alignment.topLeft'),
        ),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'maskWipeOut'})),
        contains('Animation.maskWipeOut()'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'glitchIn', 'from': 'left'})),
        contains('Animation.glitchIn(from: Edge.left)'),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'glitchOut', 'to': 'right'})),
        contains('Animation.glitchOut(to: Edge.right)'),
      );
      expect(
        printVideoSpecJson(
          _animated({'preset': 'float', 'amplitude': 0.08, 'period': '2s', 'seed': 'bob'}),
        ),
        allOf(
          contains('Animation.float('),
          contains('amplitude: 0.08'),
          contains('period: 2.seconds'),
          contains("seed: 'bob'"),
        ),
      );
      expect(
        printVideoSpecJson(_animated({'preset': 'pulse', 'min': 0.9, 'max': 1.1, 'period': '1s'})),
        allOf(contains('Animation.pulse('), contains('min: 0.9'), contains('max: 1.1')),
      );
    });
  });
}
