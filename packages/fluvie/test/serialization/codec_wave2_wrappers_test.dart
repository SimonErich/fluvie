import 'package:flutter/rendering.dart' show BoxFit, Color, Offset, Rect;
import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show
        Box,
        Callout,
        DeviceFrame,
        LowerThird,
        Markdown,
        Placed,
        Snapshot,
        Spotlight,
        TitleCard,
        unknownSpecProps;
import 'package:fluvie/src/animation/motion_target.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/snapshot/render/device_frame_painter.dart'
    show DeviceFrameStyle;
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// Round-trips one element through the spec layer and returns the widget it
/// builds; the wrappers build unwrapped (no scene-filling expand box).
Object _build(Map<String, Object?> json) {
  final anchors = AnchorTable();
  final spec = ElementSpec.fromJson(json, anchors);
  expect(spec.toJson(), json, reason: 'the codec round-trip is identity');
  return spec.build(anchors);
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
  group('Snapshot', () {
    test('round-trips and builds with a child and fit', () {
      final widget =
          _build({
                'type': 'Snapshot',
                'fit': 'cover',
                'child': {'type': 'Text', 'text': 'frozen'},
              })
              as Snapshot;
      expect(widget.fit, BoxFit.cover);
      expect((widget.child as Text).data, 'frozen');
    });

    test('fit elides to contain', () {
      final widget =
          _build({
                'type': 'Snapshot',
                'child': {'type': 'Text', 'text': 'x'},
              })
              as Snapshot;
      expect(widget.fit, BoxFit.contain);
    });

    test('a missing child errors with its path', () {
      expect(
        () => _build({'type': 'Snapshot'}),
        throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', contains('child'))),
      );
    });
  });

  group('DeviceFrame', () {
    test('phone carries its notch and defaults it on', () {
      final widget =
          _build({
                'type': 'DeviceFrame',
                'variant': 'phone',
                'notch': false,
                'child': {'type': 'Text', 'text': 'app'},
              })
              as DeviceFrame;
      expect(widget.style, DeviceFrameStyle.phone);
      expect(widget.notch, isFalse);
      final defaulted =
          _build({
                'type': 'DeviceFrame',
                'variant': 'phone',
                'child': {'type': 'Text', 'text': 'app'},
              })
              as DeviceFrame;
      expect(defaulted.notch, isTrue);
    });

    test('browser carries its url and defaults it empty', () {
      final widget =
          _build({
                'type': 'DeviceFrame',
                'variant': 'browser',
                'url': 'https://fluvie.dev',
                'child': {'type': 'Markdown', 'source': '# Hi'},
              })
              as DeviceFrame;
      expect(widget.style, DeviceFrameStyle.browser);
      expect(widget.url, 'https://fluvie.dev');
      expect((widget.child as Markdown).source, '# Hi');
      final bare =
          _build({
                'type': 'DeviceFrame',
                'variant': 'browser',
                'child': {'type': 'Text', 'text': 'x'},
              })
              as DeviceFrame;
      expect(bare.url, isNull);
    });

    test('tablet builds', () {
      final widget =
          _build({
                'type': 'DeviceFrame',
                'variant': 'tablet',
                'child': {'type': 'Text', 'text': 'x'},
              })
              as DeviceFrame;
      expect(widget.style, DeviceFrameStyle.tablet);
    });

    test('an unknown or missing variant errors naming the allowed set', () {
      expect(
        () => _build({
          'type': 'DeviceFrame',
          'variant': 'watch',
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(
          isA<FluvieSpecError>().having(
            (e) => e.message,
            'message',
            allOf(contains('watch'), contains('phone'), contains('tablet')),
          ),
        ),
      );
      expect(
        () => _build({
          'type': 'DeviceFrame',
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('notch on a non-phone and url on a non-browser reject loudly', () {
      expect(
        () => _build({
          'type': 'DeviceFrame',
          'variant': 'browser',
          'notch': true,
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', contains('notch'))),
      );
      expect(
        () => _build({
          'type': 'DeviceFrame',
          'variant': 'tablet',
          'url': 'https://x.dev',
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', contains('url'))),
      );
    });
  });

  group('Callout', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'Callout',
                'label': 'Active users',
                'target': {'x': 220, 'y': 130},
                'labelAt': {'x': 24, 'y': 20},
                'color': '#6C5CE7',
                'child': {'type': 'Box', 'color': '#101018'},
              })
              as Callout;
      expect(widget.label, 'Active users');
      expect(widget.target, const Offset(220, 130));
      expect(widget.labelAt, const Offset(24, 20));
      expect(widget.color, const Color(0xFF6C5CE7));
      expect(widget.child, isA<Box>());
    });

    test('labelAt and color default', () {
      final widget =
          _build({
                'type': 'Callout',
                'label': 'Here',
                'target': {'x': 10, 'y': 10},
                'child': {'type': 'Text', 'text': 'x'},
              })
              as Callout;
      expect(widget.labelAt, const Offset(16, 16));
      expect(widget.color, isNull);
    });

    test('a missing label, target, or child errors', () {
      expect(
        () => _build({
          'type': 'Callout',
          'target': {'x': 1, 'y': 2},
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Callout',
          'label': 'x',
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
      expect(
        () => _build({
          'type': 'Callout',
          'label': 'x',
          'target': {'x': 1, 'y': 2},
        }),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('Spotlight', () {
    test('round-trips and builds with every prop', () {
      final widget =
          _build({
                'type': 'Spotlight',
                'region': {'x': 40, 'y': 30, 'w': 180, 'h': 120},
                'reveal': '18f',
                'color': '#CC000000',
                'child': {
                  'type': 'Image',
                  'source': {'kind': 'asset', 'value': 'dashboard.png'},
                },
              })
              as Spotlight;
      expect(widget.region, const Rect.fromLTWH(40, 30, 180, 120));
      expect(widget.reveal, const Time.frames(18));
      expect(widget.color, const Color(0xCC000000));
    });

    test('reveal and color default', () {
      final widget =
          _build({
                'type': 'Spotlight',
                'region': {'x': 0, 'y': 0, 'w': 10, 'h': 10},
                'child': {'type': 'Text', 'text': 'x'},
              })
              as Spotlight;
      expect(widget.reveal, isNull);
      expect(widget.color, const Color(0xB3000000));
    });

    test('a missing region errors with its path', () {
      expect(
        () => _build({
          'type': 'Spotlight',
          'child': {'type': 'Text', 'text': 'x'},
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', contains('region'))),
      );
    });
  });

  group('child recursion', () {
    test('a child with animate and transform builds placed and animated', () {
      final widget =
          _build({
                'type': 'DeviceFrame',
                'variant': 'browser',
                'child': {
                  'type': 'Markdown',
                  'source': '# Hi',
                  'transform': {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.8},
                  'animate': [
                    {'preset': 'fadeIn'},
                  ],
                },
              })
              as DeviceFrame;
      final placed = widget.child as Placed;
      final animated = placed.child as MotionTarget;
      expect(animated.child, isA<Markdown>());
    });

    test('wrappers nest each other', () {
      final widget =
          _build({
                'type': 'Spotlight',
                'region': {'x': 0, 'y': 0, 'w': 10, 'h': 10},
                'child': {
                  'type': 'DeviceFrame',
                  'variant': 'tablet',
                  'child': {'type': 'Box', 'color': '#101018'},
                },
              })
              as Spotlight;
      final frame = widget.child as DeviceFrame;
      expect(frame.child, isA<Box>());
    });

    test('an unknown child type errors with the child path', () {
      expect(
        () => _build({
          'type': 'Snapshot',
          'child': {'type': 'Nope'},
        }),
        throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', contains('child'))),
      );
    });

    test('a non-object child errors', () {
      expect(
        () => _build({'type': 'Snapshot', 'child': 'text'}),
        throwsA(isA<FluvieSpecError>().having((e) => e.path, 'path', contains('child'))),
      );
    });
  });

  group('LowerThird and TitleCard children', () {
    test('a LowerThird child round-trips and builds', () {
      final widget =
          _build({
                'type': 'LowerThird',
                'name': 'Ada',
                'child': {'type': 'Text', 'text': 'behind the bar'},
              })
              as LowerThird;
      expect((widget.child! as Text).data, 'behind the bar');
    });

    test('a TitleCard child round-trips and builds', () {
      final widget =
          _build({
                'type': 'TitleCard',
                'title': 'One',
                'child': {'type': 'Box', 'color': '#101018'},
              })
              as TitleCard;
      expect(widget.child, isA<Box>());
    });
  });

  group('validation recurses into children', () {
    test('a typo inside a child reports with the child path', () {
      final warnings = unknownSpecProps(
        _doc({
          'type': 'Callout',
          'label': 'x',
          'target': {'x': 1, 'y': 2},
          'child': {'type': 'Box', 'colour': '#FF0000'},
        }),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.path, contains('child'));
    });

    test('a typo two children deep still reports', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Spotlight',
            'region': {'x': 0, 'y': 0, 'w': 1, 'h': 1},
            'child': {
              'type': 'DeviceFrame',
              'variant': 'phone',
              'child': {'type': 'Text', 'text': 'x', 'txt': 'y'},
            },
          }),
        ),
        isNotEmpty,
      );
    });

    test('typos inside the wrapper geometry report', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Callout',
            'label': 'x',
            'target': {'x': 1, 'y': 2, 'z': 3},
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        isNotEmpty,
      );
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Spotlight',
            'region': {'x': 0, 'y': 0, 'w': 1, 'h': 1, 'depth': 2},
            'child': {'type': 'Text', 'text': 'x'},
          }),
        ),
        isNotEmpty,
      );
    });

    test('a clean wrapper document reports none', () {
      expect(
        unknownSpecProps(
          _doc({
            'type': 'Snapshot',
            'fit': 'cover',
            'child': {
              'type': 'DeviceFrame',
              'variant': 'browser',
              'url': 'https://fluvie.dev',
              'child': {'type': 'Markdown', 'source': '# Hi'},
            },
          }),
        ),
        isEmpty,
      );
    });
  });
}
