import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show instantiateImageCodec;

import 'package:flutter/widgets.dart' hide Clip;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

RenderHostContext host(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return RenderHostContext(
    pumpWidget: tester.pumpWidget,
    pumpFrame: () => tester.pump(),
    runAsync: tester.runAsync,
    setViewSize: (w, h) {
      tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
      tester.view.devicePixelRatio = 1;
    },
  );
}

Video video(Widget child) => Video(
  width: 16,
  height: 16,
  scenes: [
    Scene(duration: 3.frames, children: [child]),
  ],
);

void main() {
  testWidgets('fresh preparation errors retain baseline evidence and their actual cause', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_preparation_error_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    await runFluvieRender(
      video: video(const SizedBox.expand()),
      videoFactory: () => video(
        const Column(
          children: [
            SizedBox(
              child: Snapshot(key: ValueKey('same'), child: SizedBox(width: 2, height: 2)),
            ),
            SizedBox(
              child: Snapshot(key: ValueKey('same'), child: SizedBox(width: 2, height: 2)),
            ),
          ],
        ),
      ),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final determinism = report['determinism']! as Map<String, Object?>;
    final mismatch = (determinism['mismatches']! as List).single as Map<String, Object?>;
    expect(mismatch['code'], 'fresh_mount_failed');
    expect(mismatch['message'], contains('Snapshot keys must be unique'));
    expect(File('${workspace.path}/frame_0.png').existsSync(), true);
  });

  testWidgets('fresh factory errors preserve baseline samples and name the failed check', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_factory_error_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    await runFluvieRender(
      video: video(const SizedBox.expand()),
      videoFactory: () => throw StateError('missing factory input'),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0, 2],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    expect(report['samples'], hasLength(2));
    final determinism = report['determinism']! as Map<String, Object?>;
    final mismatch = (determinism['mismatches']! as List).single as Map<String, Object?>;
    expect(determinism['ok'], false);
    expect(mismatch['code'], 'fresh_mount_failed');
    expect(mismatch['check'], 'fresh_mount');
    expect(mismatch['message'], contains('missing factory input'));
    expect(File('${workspace.path}/frame_2.png').existsSync(), true);
  });

  testWidgets('fresh factory changes to duration produce scoped diagnostics', (tester) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_shape_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    await runFluvieRender(
      video: video(const SizedBox.expand()),
      videoFactory: () => Video(
        width: 16,
        height: 16,
        scenes: [
          Scene(duration: 1.frames, children: const [SizedBox.expand()]),
        ],
      ),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewDeterminism: true,
        reviewFrames: [0, 2],
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final determinism = report['determinism']! as Map<String, Object?>;
    final mismatch = (determinism['mismatches']! as List).single as Map<String, Object?>;
    expect(mismatch['code'], 'fresh_mount_changes_composition');
    expect(mismatch['check'], 'fresh_mount');
    expect(mismatch['expected'], containsPair('frameCount', 3));
    expect(mismatch['actual'], containsPair('frameCount', 1));
  });

  testWidgets('cancelling fresh preparation disposes widgets and preserves baseline evidence', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_cancel_mount_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    final renderHost = host(tester);
    var mounts = 0;
    var disposals = 0;
    await expectLater(
      runFluvieRender(
        video: video(
          _MountColor(
            onMount: () {
              if (++mounts == 2) renderHost.cancellation.cancel();
              return mounts;
            },
            onDispose: () => disposals++,
          ),
        ),
        host: renderHost,
        invocation: RenderInvocation(
          outputDir: workspace.path,
          operation: 'review',
          reviewFrames: [0],
          reviewDeterminism: true,
        ),
      ),
      throwsA(isA<RenderCancelledException>()),
    );
    expect(mounts, 2);
    expect(disposals, 2);
    expect(File('${workspace.path}/frame_0.png').existsSync(), true);
    expect(File('${workspace.path}/render-result.json').existsSync(), false);
  });

  testWidgets('cancelling a waiting entry factory returns and releases the original mount', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_cancel_factory_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    final renderHost = host(tester);
    final pending = Completer<Video>();
    var disposals = 0;
    await expectLater(
      runFluvieRender(
        video: video(_MountColor(onMount: () => 1, onDispose: () => disposals++)),
        videoFactory: () {
          renderHost.cancellation.cancel();
          return pending.future;
        },
        host: renderHost,
        invocation: RenderInvocation(
          outputDir: workspace.path,
          operation: 'review',
          reviewFrames: [0],
          reviewDeterminism: true,
        ),
      ),
      throwsA(isA<RenderCancelledException>()),
    );
    expect(disposals, 1);
    expect(File('${workspace.path}/frame_0.png').existsSync(), true);
    expect(File('${workspace.path}/render-result.json').existsSync(), false);
    pending.complete(video(const SizedBox.expand()));
  });

  testWidgets('fresh snapshots are captured again without retaining the first mount state', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_fresh_snapshots_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    var mounts = 0;
    var disposals = 0;
    await runFluvieRender(
      video: video(
        Snapshot(
          child: _MountColor(
            onMount: () => ++mounts,
            onDispose: () => disposals++,
          ),
        ),
      ),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0, 2],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final samples = (report['samples']! as List).cast<Map<String, Object?>>().toList();
    expect(samples.first['sha256'], samples.last['sha256']);
    final determinism = report['determinism']! as Map<String, Object?>;
    expect(determinism['ok'], false);
    expect(
      (determinism['mismatches']! as List).every(
        (item) => (item as Map<String, Object?>)['check'] == 'fresh_mount',
      ),
      true,
    );
    expect(mounts, 2);
    expect(disposals, 2);
  });

  testWidgets('review re-evaluates the entry factory and retains original sample pictures', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_factory_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    var builds = 0;
    Video build() => video(
      ColoredBox(
        color: ++builds == 1 ? const Color(0xffff0000) : const Color(0xff00ff00),
        child: const SizedBox.expand(),
      ),
    );
    await runFluvieRender(
      video: build(),
      videoFactory: build,
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0, 2],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final determinism = report['determinism']! as Map<String, Object?>;
    expect(builds, 2);
    expect(determinism['ok'], false);
    final checks = (determinism['checks']! as List).cast<Map<String, Object?>>();
    expect(checks.first, containsPair('ok', true));
    expect(checks.last, containsPair('factoryEvaluated', true));
    expect(checks.last, containsPair('ok', false));
    final samples = (report['samples']! as List).cast<Map<String, Object?>>();
    final codec = await tester.runAsync(
      () => instantiateImageCodec(
        File(samples.first['filePath']! as String).readAsBytesSync(),
      ),
    );
    final image = (await tester.runAsync(codec!.getNextFrame))!.image;
    final rgba = await tester.runAsync(image.toByteData);
    expect(rgba!.buffer.asUint8List().take(4), [255, 0, 0, 255]);
    image.dispose();
    codec.dispose();
  });

  testWidgets('review catches mount-time choices and disposes both mounted trees', (tester) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_fresh_mount_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    var mounts = 0;
    var disposals = 0;
    await runFluvieRender(
      video: video(
        _MountColor(
          onMount: () => ++mounts,
          onDispose: () => disposals++,
        ),
      ),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0, 2],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final determinism = report['determinism']! as Map<String, Object?>;
    expect(determinism['ok'], false);
    expect(
      (determinism['mismatches']! as List).first,
      containsPair('code', 'fresh_mount_changes_pixels'),
    );
    expect(mounts, 2);
    expect(disposals, 2);
  });

  testWidgets('automatic review samples stay bounded for compositions with many scenes', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_many_scenes_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    await runFluvieRender(
      video: Video(
        width: 16,
        height: 16,
        scenes: [
          for (var index = 0; index < 30; index++)
            Scene(
              duration: 1.frames,
              children: const [ColoredBox(color: Color(0xffff0000))],
            ),
        ],
      ),
      host: host(tester),
      invocation: RenderInvocation(outputDir: workspace.path, operation: 'review'),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final samples = (report['samples']! as List<Object?>).cast<Map<String, Object?>>().toList();
    expect(samples, hasLength(24));
    expect(samples.first['frame'], 0);
    expect(samples.last['frame'], 29);
    expect(samples.map((sample) => sample['frame']).toSet(), hasLength(24));
  });

  testWidgets('review freezes authored snapshots before seeking sample pictures', (tester) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_snapshots_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    await runFluvieRender(
      video: video(
        Snapshot(
          child: FrameBuilder(
            (frame) => ColoredBox(
              color: frame.frame == 1 ? const Color(0xff00ff00) : const Color(0xffff0000),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0, 2],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    final samples = (report['samples']! as List<Object?>).cast<Map<String, Object?>>().toList();
    expect(samples.first['sha256'], samples.last['sha256']);
    expect(report['determinism'], containsPair('ok', true));
  });
  testWidgets('review captures exact samples and compares reverse seeks in one mounted session', (
    tester,
  ) async {
    final workspace = Directory.systemTemp.createTempSync('fluvie_review_host_');
    addTearDown(() => workspace.deleteSync(recursive: true));
    await runFluvieRender(
      video: video(
        FrameBuilder(
          (context) => ColoredBox(
            color: context.frame == 0 ? const Color(0xffff0000) : const Color(0xff00ff00),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      host: host(tester),
      invocation: RenderInvocation(
        outputDir: workspace.path,
        operation: 'review',
        reviewFrames: [0, 2],
        reviewDeterminism: true,
      ),
    );
    final report =
        jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
            as Map<String, Object?>;
    expect(report['totalFrames'], 3);
    expect(report['samples'], hasLength(2));
    final samples = (report['samples']! as List<Object?>).cast<Map<String, Object?>>();
    expect(samples.map((sample) => sample['frame']), [0, 2]);
    expect(samples.first['sha256'], isNot(samples.last['sha256']));
    for (final sample in samples) {
      expect(File(sample['filePath']! as String).readAsBytesSync().take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
    }
    expect(report['determinism'], containsPair('ok', true));
    expect(File('${workspace.path}/frames.rgba').existsSync(), isFalse);
  });

  testWidgets(
    'review reports history-dependent custom Flutter state instead of claiming deterministic output',
    (tester) async {
      final workspace = Directory.systemTemp.createTempSync('fluvie_review_state_');
      addTearDown(() => workspace.deleteSync(recursive: true));
      await runFluvieRender(
        video: video(const _HistoryColor()),
        host: host(tester),
        invocation: RenderInvocation(
          outputDir: workspace.path,
          operation: 'review',
          reviewFrames: [0, 2],
          reviewDeterminism: true,
        ),
      );
      final report =
          jsonDecode(File('${workspace.path}/review.json').readAsStringSync())
              as Map<String, Object?>;
      expect(report['determinism'], containsPair('ok', false));
      final determinism = report['determinism']! as Map<String, Object?>;
      expect(determinism['mismatches'], isNotEmpty);
    },
  );
}

class _MountColor extends StatefulWidget {
  const _MountColor({required this.onMount, required this.onDispose});
  final int Function() onMount;
  final void Function() onDispose;
  @override
  State<_MountColor> createState() => _MountColorState();
}

class _MountColorState extends State<_MountColor> {
  late Color color;
  @override
  void initState() {
    super.initState();
    color = Color.fromARGB(255, widget.onMount() * 30, 0, 0);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(color: color, child: const SizedBox.expand());

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

class _HistoryColor extends StatefulWidget {
  const _HistoryColor();
  @override
  State<_HistoryColor> createState() => _HistoryColorState();
}

class _HistoryColorState extends State<_HistoryColor> {
  int lastFrame = -1;
  int changes = 0;
  @override
  Widget build(BuildContext context) => FrameBuilder((frame) {
    if (frame.frame != lastFrame) {
      changes++;
      lastFrame = frame.frame;
    }
    return ColoredBox(
      color: Color.fromARGB(255, (changes * 10) % 256, 0, 0),
      child: const SizedBox.expand(),
    );
  });
}
