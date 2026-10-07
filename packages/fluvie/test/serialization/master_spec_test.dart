import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart'
    show
        AnchorTable,
        MasterElementSpec,
        MasterSpec,
        PlaceholderSpec,
        SceneLayout,
        Video,
        VideoSpec,
        resolveSceneMaster;
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';

/// A representative master: a color background, canvas layout, one fixed
/// chrome child, a styled title placeholder, and a bare body placeholder.
Map<String, Object?> _masterJson() => {
  'background': {'kind': 'color', 'color': '#FF101018'},
  'layout': 'canvas',
  'children': [
    {
      'type': 'Box',
      'color': '#FF6C5CE7',
      'transform': {'x': 0.5, 'y': 0.94, 'w': 1.0, 'h': 0.06},
    },
    {
      'type': 'Placeholder',
      'slot': 'title',
      'transform': {'x': 0.5, 'y': 0.24, 'w': 0.9, 'h': 0.28},
      'style': {'color': '#FFF5F6FA', 'fontSize': 34, 'fontWeight': 'w700'},
    },
    {
      'type': 'Placeholder',
      'slot': 'body',
      'transform': {'x': 0.5, 'y': 0.62, 'w': 0.86, 'h': 0.34},
    },
  ],
};

/// A whole document: the master above plus [scenes].
Map<String, Object?> _document({
  required List<Map<String, Object?>> scenes,
  Map<String, Object?>? master,
}) => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'masters': {'content': master ?? _masterJson()},
  'scenes': scenes,
};

/// An adopting scene: a transform-overriding title fill, a bare body fill,
/// and one freeform extra child on top.
Map<String, Object?> _adoptingScene() => {
  'duration': '90f',
  'master': 'content',
  'fills': <String, Object?>{
    'title': {
      'type': 'Text',
      'id': 's1-title',
      'text': 'Adopted title',
      'textAlign': 'center',
      'transform': {'x': 0.5, 'y': 0.14, 'w': 0.9, 'h': 0.24},
    },
    'body': {
      'type': 'Text',
      'id': 's1-body',
      'text': 'Slide one body',
      'textAlign': 'center',
      'style': {'color': '#FFB2BEC3', 'fontSize': 20},
    },
  },
  'children': [
    {
      'type': 'Box',
      'id': 's1-extra',
      'color': '#FFFFD166',
      'transform': {'x': 0.85, 'y': 0.1, 'w': 0.16, 'h': 0.1},
    },
  ],
};

Matcher _specError(Object message, {List<String>? path}) {
  var matcher = isA<FluvieSpecError>().having((e) => e.message, 'message', message);
  if (path != null) matcher = matcher.having((e) => e.path, 'path', path);
  return throwsA(matcher);
}

void main() {
  group('MasterSpec parses and round-trips', () {
    test('a full master round-trips identically', () {
      final master = MasterSpec.fromJson(_masterJson(), AnchorTable());
      expect(master.toJson(), _masterJson());
      expect(master.layout, SceneLayout.canvas);
      expect(master.background, isNotNull);
      expect(master.children, hasLength(3));
      expect(master.children.first, isA<MasterElementSpec>());
      final title = master.children[1];
      expect(title, isA<PlaceholderSpec>());
      expect((title as PlaceholderSpec).slot, 'title');
      expect(title.placement, isNotNull);
      expect(title.style, isNotNull);
      expect(master.slots, {'title', 'body'});
    });

    test('an empty master parses: no background, stack layout, no children', () {
      final master = MasterSpec.fromJson(const {}, AnchorTable());
      expect(master.background, isNull);
      expect(master.layout, SceneLayout.stack);
      expect(master.children, isEmpty);
      expect(master.slots, isEmpty);
      expect(master.toJson(), isEmpty);
    });

    test('an unknown layout fails with the allowed values', () {
      expect(
        () => MasterSpec.fromJson(const {'layout': 'grid'}, AnchorTable(), path: const ['m']),
        _specError(contains('"grid"'), path: ['m', 'layout']),
      );
    });

    test('a master child must be an object', () {
      expect(
        () => MasterSpec.fromJson(
          const {
            'children': ['nope'],
          },
          AnchorTable(),
          path: const ['m'],
        ),
        _specError(contains('object'), path: ['m', 'children', '0']),
      );
    });

    test('a placeholder needs an identifier slot', () {
      expect(
        () => MasterSpec.fromJson(
          const {
            'children': [
              {'type': 'Placeholder'},
            ],
          },
          AnchorTable(),
          path: const ['m'],
        ),
        _specError(contains('"slot"'), path: ['m', 'children', '0']),
      );
      expect(
        () => MasterSpec.fromJson(const {
          'children': [
            {'type': 'Placeholder', 'slot': '2bad'},
          ],
        }, AnchorTable()),
        _specError(contains('"2bad"')),
      );
    });

    test('duplicate slots in one master fail loudly', () {
      expect(
        () => MasterSpec.fromJson(
          const {
            'children': [
              {'type': 'Placeholder', 'slot': 'title'},
              {'type': 'Placeholder', 'slot': 'title'},
            ],
          },
          AnchorTable(),
          path: const ['m'],
        ),
        _specError(contains('"title"'), path: ['m', 'children', '1']),
      );
    });

    test('a placeholder style must be an object', () {
      expect(
        () => MasterSpec.fromJson(const {
          'children': [
            {'type': 'Placeholder', 'slot': 'title', 'style': 'bold'},
          ],
        }, AnchorTable()),
        _specError(contains('object')),
      );
    });

    test('identity keys are forbidden on master children, at any depth', () {
      for (final key in const ['id', 'anchor', 'shared']) {
        expect(
          () => MasterSpec.fromJson(
            {
              'children': [
                {'type': 'Box', 'color': '#FF000000', key: 'chrome'},
              ],
            },
            AnchorTable(),
            path: const ['m'],
          ),
          _specError(contains('"$key"'), path: ['m', 'children', '0']),
          reason: 'top-level $key must be rejected',
        );
      }
      expect(
        () => MasterSpec.fromJson(const {
          'children': [
            {
              'type': 'Group',
              'children': [
                {'type': 'Box', 'color': '#FF000000', 'id': 'nested'},
              ],
            },
          ],
        }, AnchorTable()),
        _specError(contains('"id"'), path: ['children', '0', 'children', '0']),
      );
      expect(
        () => MasterSpec.fromJson(const {
          'children': [
            {
              'type': 'Snapshot',
              'child': {'type': 'Text', 'text': 'x', 'anchor': 'a'},
            },
          ],
        }, AnchorTable()),
        _specError(contains('"anchor"'), path: ['children', '0', 'child']),
      );
    });
  });

  group('the masters block on the video', () {
    test('masters parse, round-trip, and elide when empty', () {
      final doc = _document(scenes: [_adoptingScene()]);
      final spec = VideoSpec.fromJson(doc);
      expect(spec.masters.keys, ['content']);
      expect(spec.toJson()['masters'], doc['masters']);
      final bare = VideoSpec.fromJson(const {
        'scenes': [
          {'duration': '60f'},
        ],
      });
      expect(bare.masters, isEmpty);
      expect(bare.toJson().containsKey('masters'), isFalse);
    });

    test('masters must be an object of identifier names', () {
      expect(
        () =>
            VideoSpec.fromJson({'masters': <Object?>[], 'scenes': _document(scenes: [])['scenes']}),
        _specError(contains('object'), path: ['masters']),
      );
      expect(
        () => VideoSpec.fromJson({
          'masters': {'2bad': <String, Object?>{}},
          'scenes': [
            {'duration': '60f'},
          ],
        }),
        _specError(contains('"2bad"'), path: ['masters']),
      );
    });

    test('a Placeholder is rejected in scene children', () {
      expect(
        () => VideoSpec.fromJson(
          _document(
            scenes: [
              {
                'duration': '60f',
                'children': [
                  {'type': 'Placeholder', 'slot': 'title'},
                ],
              },
            ],
          ),
        ),
        _specError(contains('master'), path: ['scenes', '0', 'children', '0']),
      );
    });

    test('a Placeholder is rejected as a fill', () {
      final scene = _adoptingScene();
      (scene['fills']! as Map<String, Object?>)['body'] = {'type': 'Placeholder', 'slot': 'x'};
      expect(
        () => VideoSpec.fromJson(_document(scenes: [scene])),
        _specError(contains('master'), path: ['scenes', '0', 'fills', 'body']),
      );
    });

    test('fills without a master fail loudly', () {
      expect(
        () => VideoSpec.fromJson(
          _document(
            scenes: [
              {
                'duration': '60f',
                'fills': {
                  'title': {'type': 'Text', 'text': 'x'},
                },
              },
            ],
          ),
        ),
        _specError(contains('master'), path: ['scenes', '0', 'fills']),
      );
    });

    test('an unknown master name fails naming the known masters', () {
      final scene = _adoptingScene()..['master'] = 'missing';
      expect(
        () => VideoSpec.fromJson(_document(scenes: [scene])),
        _specError(
          allOf(contains('"missing"'), contains('"content"')),
          path: ['scenes', '0', 'master'],
        ),
      );
    });

    test('a fill for an unknown slot fails naming the known slots', () {
      final scene = _adoptingScene();
      (scene['fills']! as Map<String, Object?>)['footer'] = {'type': 'Text', 'text': 'x'};
      expect(
        () => VideoSpec.fromJson(_document(scenes: [scene])),
        _specError(
          allOf(contains('"footer"'), contains('"title"'), contains('"body"')),
          path: ['scenes', '0', 'fills', 'footer'],
        ),
      );
    });

    test('a fill must be an element object', () {
      final scene = _adoptingScene();
      (scene['fills']! as Map<String, Object?>)['title'] = 'nope';
      expect(
        () => VideoSpec.fromJson(_document(scenes: [scene])),
        _specError(contains('object'), path: ['scenes', '0', 'fills', 'title']),
      );
    });

    test('a scene with master and fills round-trips identically', () {
      final doc = _document(scenes: [_adoptingScene()]);
      final once = VideoSpec.fromJson(doc).toJson();
      expect(once['scenes'], doc['scenes']);
      expect(VideoSpec.fromJson(once).toJson(), once);
    });
  });

  group('resolveSceneMaster', () {
    VideoSpec spec(List<Map<String, Object?>> scenes) => VideoSpec.fromJson(
      _document(scenes: scenes),
    );

    test('a scene without a master passes through untouched', () {
      final parsed = spec([
        {
          'duration': '60f',
          'children': [
            {'type': 'Text', 'id': 'free', 'text': 'Freeform'},
          ],
        },
      ]);
      final scene = parsed.scenes.single;
      expect(identical(resolveSceneMaster(scene, parsed.masters), scene), isTrue);
    });

    test('adoption layers master chrome, filled placeholders, then scene children', () {
      final parsed = spec([_adoptingScene()]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.children, hasLength(4));
      expect(resolved.children[0].type, 'Box');
      expect(resolved.children[0].id, isNull);
      expect(resolved.children[1].id, 's1-title');
      expect(resolved.children[2].id, 's1-body');
      expect(resolved.children[3].id, 's1-extra');
      expect(resolved.master, isNull);
      expect(resolved.fills, isEmpty);
    });

    test('the master background applies unless the scene declares its own', () {
      final parsed = spec([
        _adoptingScene(),
        {
          'duration': '60f',
          'background': {'kind': 'color', 'color': '#FF2D3436'},
          'master': 'content',
        },
      ]);
      final inherited = resolveSceneMaster(parsed.scenes[0], parsed.masters);
      expect(inherited.background!.props['color'], '#FF101018');
      final own = resolveSceneMaster(parsed.scenes[1], parsed.masters);
      expect(own.background!.props['color'], '#FF2D3436');
    });

    test('an unfilled slot renders nothing', () {
      final parsed = spec([
        {
          'duration': '60f',
          'master': 'content',
          'fills': {
            'title': {'type': 'Text', 'id': 't', 'text': 'Only the title'},
          },
        },
      ]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.children, hasLength(2));
      expect([for (final child in resolved.children) child.type], ['Box', 'Text']);
    });

    test('a fill transform overrides the placeholder transform', () {
      final parsed = spec([_adoptingScene()]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.children[1].placement!.y, 0.14);
      expect(resolved.children[2].placement!.y, 0.62);
    });

    test('placeholder style merges under the fill style, fill winning per field', () {
      final parsed = spec([
        {
          'duration': '60f',
          'master': 'content',
          'fills': {
            'title': {
              'type': 'Text',
              'id': 't',
              'text': 'x',
              'style': {'fontSize': 48},
            },
          },
        },
      ]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.children[1].props['style'], {
        'color': '#FFF5F6FA',
        'fontSize': 48,
        'fontWeight': 'w700',
      });
    });

    test('a style-less fill adopts the placeholder style whole', () {
      final parsed = spec([_adoptingScene()]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.children[1].props['style'], {
        'color': '#FFF5F6FA',
        'fontSize': 34,
        'fontWeight': 'w700',
      });
      expect(resolved.children[2].props['style'], {'color': '#FFB2BEC3', 'fontSize': 20});
    });

    test('a style-less placeholder leaves the fill props untouched', () {
      final parsed = spec([
        {
          'duration': '60f',
          'master': 'content',
          'fills': {
            'body': {'type': 'Text', 'id': 'b', 'text': 'bare'},
          },
        },
      ]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.children[1].props.containsKey('style'), isFalse);
    });

    test('a fill keeps its animations, anchor, and visibility', () {
      final parsed = spec([
        {
          'duration': '60f',
          'master': 'content',
          'fills': {
            'title': {
              'type': 'Text',
              'id': 't',
              'text': 'x',
              'anchor': 'headline',
              'visible': false,
              'animate': [
                {'preset': 'fadeIn', 'duration': '15f'},
              ],
            },
          },
        },
      ]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      final title = resolved.children[1];
      expect(title.anchor, 'headline');
      expect(title.visible, isFalse);
      expect(title.animate, hasLength(1));
    });

    test('steps and notes ride the resolved scene unchanged', () {
      final scene = _adoptingScene()
        ..['steps'] = [
          {
            'elements': ['s1-body'],
          },
        ]
        ..['notes'] = {'text': 'speak'};
      final parsed = spec([scene]);
      final resolved = resolveSceneMaster(parsed.scenes.single, parsed.masters);
      expect(resolved.steps, hasLength(1));
      expect(resolved.notes!.text, 'speak');
    });

    test('a hand-built scene resolving an unknown master fails loudly', () {
      final parsed = spec([_adoptingScene()]);
      expect(
        () => resolveSceneMaster(parsed.scenes.single, const {}),
        _specError(contains('"content"')),
      );
    });
  });

  group('build-time application, no copies', () {
    test('editing the master changes every adopting scene on the next build', () {
      final doc = _document(
        scenes: [
          _adoptingScene(),
          {
            'duration': '90f',
            'master': 'content',
            'fills': {
              'title': {'type': 'Text', 'id': 's2-title', 'text': 'Second'},
            },
          },
        ],
      );
      final before = VideoSpec.fromJson(doc);
      for (final scene in before.scenes) {
        expect(
          resolveSceneMaster(scene, before.masters).children.first.props['color'],
          '#FF6C5CE7',
        );
      }
      final edited = before.toJson();
      final master =
          (edited['masters']! as Map<String, Object?>)['content']! as Map<String, Object?>;
      (master['children']! as List)[0] = {
        'type': 'Box',
        'color': '#FF00B894',
        'transform': {'x': 0.5, 'y': 0.94, 'w': 1.0, 'h': 0.06},
      };
      final after = VideoSpec.fromJson(edited);
      for (final scene in after.scenes) {
        expect(
          resolveSceneMaster(scene, after.masters).children.first.props['color'],
          '#FF00B894',
        );
      }
    });

    test('VideoSpec.build applies masters', () {
      expect(VideoSpec.fromJson(_document(scenes: [_adoptingScene()])).build(), isA<Video>());
    });

    test('a master edit moves the digest; the editor block still does not', () {
      final doc = _document(scenes: [_adoptingScene()]);
      final base = VideoSpec.fromJson(doc).digest();
      final retinted = _document(scenes: [_adoptingScene()]);
      final master =
          (retinted['masters']! as Map<String, Object?>)['content']! as Map<String, Object?>;
      (master['background']! as Map<String, Object?>)['color'] = '#FF000000';
      expect(VideoSpec.fromJson(retinted).digest(), isNot(base));
      final annotated = _document(scenes: [_adoptingScene()])..['editor'] = {'note': 'ignored'};
      expect(VideoSpec.fromJson(annotated).digest(), base);
    });
  });
}
