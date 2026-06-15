// WI-6 (D3): the static media collect-pass. `collectMediaSources(scenes)`
// walks the declared scene/children widget trees (and each scene's
// Background) gathering every Image source + Background media field, without
// mounting anything and with no async. Deduplicates across scenes; walks the
// common layout widgets and through MotionTarget (the `.animate()` wrapper).

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/animate_extension.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/box.dart';
import 'package:fluvie/src/composition/frame.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/clip.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/elements/mermaid/mermaid.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_theme.dart';
import 'package:fluvie/src/elements/snapshot/device_frame.dart';
import 'package:fluvie/src/elements/snapshot/snapshot.dart';
import 'package:fluvie/src/elements/webview/webview.dart';

const _logo = MediaSource.asset('fixtures/swatch.png');
const _bg = MediaSource.asset('fixtures/bg.png');
const _movie = MediaSource.asset('fixtures/clip_1s.mp4');
final _photo = MediaSource.network(Uri.parse('https://example.com/p.jpg'));

Scene _scene({Background? background, List<Widget> children = const []}) =>
    Scene(duration: const Time.seconds(1), background: background, children: children);

void main() {
  group('collectMediaSources (WI-6, D3)', () {
    test('a media-less tree yields the empty set', () {
      final scenes = [
        _scene(
          children: const [
            SizedBox(),
            Box(color: Color(0xFF000000)),
          ],
        ),
      ];
      expect(collectMediaSources(scenes), isEmpty);
    });

    test('collects a direct Image child', () {
      final scenes = [
        _scene(children: [Image.asset('fixtures/swatch.png')]),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('collects a Clip child (via the MediaCarrier marker)', () {
      final scenes = [
        _scene(children: [Clip.asset('fixtures/clip_1s.mp4')]),
      ];
      expect(collectMediaSources(scenes), {_movie});
    });

    test('collects a Clip nested in a layout and animated', () {
      final scenes = [
        _scene(
          children: [
            Center(child: Clip.asset('fixtures/clip_1s.mp4').animate(const [])),
          ],
        ),
      ];
      expect(collectMediaSources(scenes), {_movie});
    });

    test('collects a scene Background.image source', () {
      final scenes = [_scene(background: Background.image('fixtures/bg.png'))];
      expect(collectMediaSources(scenes), {_bg});
    });

    test('collects a network image by Uri', () {
      final scenes = [
        _scene(children: [Image.network('https://example.com/p.jpg')]),
      ];
      expect(collectMediaSources(scenes), {_photo});
    });

    test('deduplicates the same source across scenes', () {
      final scenes = [
        _scene(children: [Image.asset('fixtures/swatch.png')]),
        _scene(children: [Image.asset('fixtures/swatch.png')]),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('walks Column / Row / Stack / Wrap / Center / Align / Padding', () {
      final scenes = [
        _scene(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    Center(child: Image.asset('fixtures/swatch.png')),
                  ],
                ),
                Stack(
                  children: [
                    Align(child: Image.network('https://example.com/p.jpg')),
                  ],
                ),
                Wrap(
                  children: [
                    Padding(
                      padding: EdgeInsets.zero,
                      child: Background.image('fixtures/bg.png'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ];
      expect(collectMediaSources(scenes), {_logo, _photo, _bg});
    });

    test('walks through a MotionTarget (.animate wrapper)', () {
      final scenes = [
        _scene(children: [Image.asset('fixtures/swatch.png').animate(const [])]),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('collects both background and children of one scene', () {
      final scenes = [
        _scene(
          background: Background.image('fixtures/bg.png'),
          children: [Image.asset('fixtures/swatch.png')],
        ),
      ];
      expect(collectMediaSources(scenes), {_bg, _logo});
    });

    test('a non-media background contributes nothing', () {
      final scenes = [_scene(background: Background.color(const Color(0xFF000000)))];
      expect(collectMediaSources(scenes), isEmpty);
    });

    test('a Mermaid contributes no MediaSource (it is a snapshot)', () {
      final scenes = [
        _scene(children: const [Mermaid('graph TD; A-->B;')]),
      ];
      expect(collectMediaSources(scenes), isEmpty);
    });

    test('descends into a DeviceFrame to collect a framed Image', () {
      final scenes = [
        _scene(children: [DeviceFrame.phone(child: Image.asset('fixtures/swatch.png'))]),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('descends into a Frame wrapping widget to collect a nested Image', () {
      final scenes = [
        _scene(children: [Frame.card(child: Image.asset('fixtures/swatch.png'))]),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('descends into a Snapshot to collect media inside the captured subtree', () {
      final scenes = [
        _scene(children: [Snapshot(child: Image.asset('fixtures/swatch.png'))]),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });
  });

  group('collectSnapshotSources (WI-12, D-Source)', () {
    test('a snapshot-less tree yields the empty set', () {
      final scenes = [
        _scene(children: [Image.asset('fixtures/swatch.png')]),
      ];
      expect(collectSnapshotSources(scenes), isEmpty);
    });

    test('collects a direct Mermaid child', () {
      final scenes = [
        _scene(children: const [Mermaid('graph TD; A-->B;')]),
      ];
      expect(collectSnapshotSources(scenes), {
        const SnapshotSource.mermaid('graph TD; A-->B;'),
      });
    });

    test('collects a Mermaid nested in a layout and animated', () {
      final scenes = [
        _scene(
          children: [
            Center(child: const Mermaid('graph TD; A-->B;').animate(const [])),
          ],
        ),
      ];
      expect(collectSnapshotSources(scenes), {
        const SnapshotSource.mermaid('graph TD; A-->B;'),
      });
    });

    test('a themed Mermaid folds its theme key into the gathered source', () {
      final scenes = [
        _scene(children: const [Mermaid('graph TD; A-->B;', theme: MermaidTheme.light())]),
      ];
      expect(collectSnapshotSources(scenes), {
        SnapshotSource.mermaid('graph TD; A-->B;', themeKey: const MermaidTheme.light().cacheKey),
      });
    });

    test('deduplicates the same diagram across scenes', () {
      final scenes = [
        _scene(children: const [Mermaid('graph TD; A-->B;')]),
        _scene(children: const [Mermaid('graph TD; A-->B;')]),
      ];
      expect(collectSnapshotSources(scenes).length, 1);
    });

    test('two differently themed diagrams are distinct entries', () {
      final scenes = [
        _scene(
          children: const [
            Mermaid('graph TD; A-->B;', theme: MermaidTheme.light()),
            Mermaid('graph TD; A-->B;', theme: MermaidTheme.dark()),
          ],
        ),
      ];
      expect(collectSnapshotSources(scenes).length, 2);
    });

    test('descends into a DeviceFrame.browser to collect a framed WebView (the headline case)', () {
      final scenes = [
        _scene(
          children: [
            DeviceFrame.browser(
              url: 'https://example.com',
              child: WebView.url(
                'https://example.com',
                viewport: const SnapshotViewport(width: 800, height: 600),
              ),
            ),
          ],
        ),
      ];
      final sources = collectSnapshotSources(scenes);
      expect(sources, hasLength(1));
      expect(sources.single, isA<UrlSnapshotSource>());
    });

    test('descends into a DeviceFrame to collect a framed Mermaid', () {
      final scenes = [
        _scene(children: const [DeviceFrame.phone(child: Mermaid('graph TD; A-->B;'))]),
      ];
      expect(collectSnapshotSources(scenes), {const SnapshotSource.mermaid('graph TD; A-->B;')});
    });
  });

  group('collectSnapshots (P12-SNAP wiring)', () {
    test('a Snapshot-less tree yields the empty list', () {
      final scenes = [
        _scene(children: [Image.asset('fixtures/swatch.png')]),
      ];
      expect(collectSnapshots(scenes), isEmpty);
    });

    test('collects a direct Snapshot widget', () {
      final snapshot = Snapshot(child: Image.asset('fixtures/swatch.png'));
      final scenes = [
        _scene(children: [snapshot]),
      ];
      expect(collectSnapshots(scenes), [same(snapshot)]);
    });

    test('collects a Snapshot nested in a layout and animated', () {
      final snapshot = Snapshot(child: Image.asset('fixtures/swatch.png'));
      final scenes = [
        _scene(
          children: [
            Center(child: snapshot.animate(const [])),
          ],
        ),
      ];
      expect(collectSnapshots(scenes), [same(snapshot)]);
    });

    test('gathers multiple Snapshots in deterministic build order', () {
      final first = Snapshot(child: Image.asset('fixtures/swatch.png'));
      final second = Snapshot(child: Image.network('https://example.com/p.jpg'));
      final scenes = [
        _scene(
          children: [
            Column(children: [first, second]),
          ],
        ),
      ];
      final gathered = collectSnapshots(scenes);
      expect(gathered, hasLength(2));
      expect(gathered[0], same(first));
      expect(gathered[1], same(second));
    });

    test('does NOT deduplicate: each Snapshot instance is its own capture', () {
      final scenes = [
        _scene(
          children: const [
            Snapshot(child: SizedBox()),
            Snapshot(child: SizedBox()),
          ],
        ),
      ];
      // Two distinct unkeyed Snapshots each need their own index-keyed raster,
      // so the collector returns a List (order-stable), never a deduped Set.
      expect(collectSnapshots(scenes), hasLength(2));
    });

    test('descends into a DeviceFrame to collect a framed Snapshot', () {
      final snapshot = Snapshot(child: Image.asset('fixtures/swatch.png'));
      final scenes = [
        _scene(children: [DeviceFrame.phone(child: snapshot)]),
      ];
      expect(collectSnapshots(scenes), [same(snapshot)]);
    });

    test('a Mermaid is not a Snapshot widget and is not collected', () {
      final scenes = [
        _scene(children: const [Mermaid('graph TD; A-->B;')]),
      ];
      expect(collectSnapshots(scenes), isEmpty);
    });
  });
}
