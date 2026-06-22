// Inspector view-model unit tests (WI-36, decision D26): pure
// ProviderContainer tests — no widgets. The launcher is a mocktail mock, so
// no process is ever spawned (the real ProcessRenderLauncher never runs in
// CI; only its input validation is exercised here).
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' hide RenderProgress;
import 'package:fluvie_example/inspector/inspector_view_model.dart';
import 'package:fluvie_example/inspector/playback_view_model.dart';
import 'package:fluvie_example/inspector/process_render_launcher.dart';
import 'package:fluvie_example/inspector/providers.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:fluvie_example/inspector/render_view_model.dart';
import 'package:mocktail/mocktail.dart';

final class _MockRenderLauncher extends Mock implements RenderLauncher {}

void main() {
  late ProviderContainer container;
  late _MockRenderLauncher launcher;

  setUp(() {
    launcher = _MockRenderLauncher();
    container = ProviderContainer(
      overrides: [renderLauncherProvider.overrideWithValue(launcher)],
    );
    addTearDown(container.dispose);
  });

  group('PlaybackViewModel (WI-36)', () {
    test('starts at frame 0 with the selected lesson total frames', () {
      final state = container.read(playbackViewModelProvider);

      // Lesson 01 is a 4 s video at 30 fps; playback always opens at frame 0.
      expect(state.frame, 0);
      expect(state.totalFrames, 120);
      expect(container.read(playbackViewModelProvider.notifier).controller.frame, 0);
    });

    test('seek drives the owned RenderController and the published state', () {
      final viewModel = container.read(playbackViewModelProvider.notifier)..seek(42);

      expect(container.read(playbackViewModelProvider).frame, 42);
      expect(viewModel.controller.frame, 42);
    });

    test('seek clamps to the playable range 0..totalFrames-1', () {
      final viewModel = container.read(playbackViewModelProvider.notifier)..seek(9999);
      expect(viewModel.controller.frame, 119);
      expect(container.read(playbackViewModelProvider).frame, 119);

      viewModel.seek(-5);
      expect(viewModel.controller.frame, 0);
      expect(container.read(playbackViewModelProvider).frame, 0);
    });

    test('selecting another lesson re-targets the controller at frame 0', () {
      container.read(selectedLessonIndexProvider.notifier).select(2);

      final state = container.read(playbackViewModelProvider);

      // Lesson 03 is a 10 s video at 30 fps; a fresh selection opens at frame 0.
      expect(state.frame, 0);
      expect(state.totalFrames, 300);
      expect(container.read(playbackViewModelProvider.notifier).controller.frame, 0);
    });

    test('lesson selection clamps to the registry range', () {
      container.read(selectedLessonIndexProvider.notifier).select(99);
      expect(container.read(selectedLessonProvider).id, '12_the_kitchen_sink');

      container.read(selectedLessonIndexProvider.notifier).select(-1);
      expect(container.read(selectedLessonProvider).id, '01_hello_video');
    });
  });

  group('InspectorViewModel (WI-18)', () {
    const timeline = ResolvedTimeline(
      fps: 30,
      totalFrames: 120,
      rows: [
        TimelineRow(
          ownerId: 's0e0:Text',
          label: 'pop',
          phase: AnimationPhase.enter,
          startFrame: 0,
          endFrame: 18,
        ),
      ],
      anchors: [TimelineAnchor(name: 'intro', frame: 0)],
      warnings: ['something overhangs'],
    );

    test('starts pending before the first resolution lands in the probe', () {
      expect(container.read(inspectorViewModelProvider), isA<InspectorPending>());
    });

    test('becomes InspectorReady with the model from a pushed ResolvedTimeline', () {
      container.read(inspectorViewModelProvider); // initialize + subscribe
      container.read(timelineProbeProvider).value = timeline;

      final state = container.read(inspectorViewModelProvider);
      expect(state, isA<InspectorReady>());
      final model = (state as InspectorReady).model;
      expect(model, InspectorModel.fromTimeline(timeline));
      expect(model.motions.single.ownerId, 's0e0:Text');
      expect(model.anchors.single.name, 'intro');
      expect(model.warnings, ['something overhangs']);
    });

    test('a fresh probe push rebuilds the model', () {
      container.read(inspectorViewModelProvider);
      container.read(timelineProbeProvider).value = timeline;
      container.read(timelineProbeProvider).value = const ResolvedTimeline(
        fps: 30,
        totalFrames: 60,
        rows: [],
      );

      final state = container.read(inspectorViewModelProvider);
      expect((state as InspectorReady).model.totalFrames, 60);
    });

    test('becomes InspectorTimingError when the probe reports an error', () {
      container.read(inspectorViewModelProvider); // initialize + subscribe
      container.read(timelineProbeProvider).reportError('no beat grid for track music');

      final state = container.read(inspectorViewModelProvider);
      expect(state, isA<InspectorTimingError>());
      expect((state as InspectorTimingError).message, 'no beat grid for track music');
    });
  });

  group('RenderViewModel (WI-36)', () {
    test('renders the selected lesson and surfaces launcher stdout and stderr', () async {
      when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenAnswer(
        (_) async => const RenderLaunchResult(
          exitCode: 0,
          stdout: 'capture: 120 frames',
          stderr: 'ffmpeg: note',
        ),
      );

      await container.read(renderViewModelProvider.notifier).render();

      final state = container.read(renderViewModelProvider);
      expect(state.running, isFalse);
      expect(state.output, contains('capture: 120 frames'));
      expect(state.output, contains('ffmpeg: note'));
      expect(state.output, contains('build/01_hello_video.mp4'));
      verify(
        () => launcher.render('01_hello_video', onProgress: any(named: 'onProgress')),
      ).called(1);
    });

    test('a failing launch reports the exit code and stderr', () async {
      when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenAnswer(
        (_) async =>
            const RenderLaunchResult(exitCode: 70, stdout: '', stderr: 'no ffmpeg on PATH'),
      );

      await container.read(renderViewModelProvider.notifier).render();

      final state = container.read(renderViewModelProvider);
      expect(state.running, isFalse);
      expect(state.output, contains('no ffmpeg on PATH'));
      expect(state.output, contains('70'));
    });

    test('a launcher that throws resets running and surfaces the error', () async {
      // A missing `dart` on PATH throws a ProcessException, not a non-zero exit.
      // Without a catch the button would hang on "Rendering ..." forever.
      when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenThrow(
        const ProcessException('dart', ['run'], 'No such file or directory', 2),
      );

      await container.read(renderViewModelProvider.notifier).render();

      final state = container.read(renderViewModelProvider);
      expect(state.running, isFalse);
      expect(state.output, contains('Render failed'));
      expect(state.output, contains('No such file or directory'));
    });

    test('a progress callback updates running state with the live frame count', () async {
      // The launcher reports progress mid-render; the view model must publish it
      // while still running so the bar can update in real time.
      RenderState? midRender;
      when(() => launcher.render(any(), onProgress: any(named: 'onProgress'))).thenAnswer((
        invocation,
      ) async {
        final onProgress = invocation.namedArguments[#onProgress] as void Function(RenderProgress)?;
        onProgress?.call(const RenderProgress(completed: 45, total: 120));
        midRender = container.read(renderViewModelProvider);
        return const RenderLaunchResult(exitCode: 0, stdout: 'done', stderr: '');
      });

      await container.read(renderViewModelProvider.notifier).render();

      expect(midRender?.running, isTrue);
      expect(midRender?.progress, const RenderProgress(completed: 45, total: 120));
      // Once finished the progress is cleared and the button re-enables.
      final state = container.read(renderViewModelProvider);
      expect(state.running, isFalse);
      expect(state.progress, isNull);
    });
  });

  group('ProcessRenderLauncher (WI-36)', () {
    test('rejects keys that are not lowercase snake_case before spawning', () async {
      const processLauncher = ProcessRenderLauncher();

      await expectLater(
        processLauncher.render('bad key; rm -rf /'),
        throwsArgumentError,
      );
    });

    test('findWorkspaceRoot walks up to the dir holding the CLI entrypoint', () {
      // A packaged desktop app runs with its cwd in example/build/.../bundle,
      // so the root must be found by walking up from an anchor to the directory
      // that actually contains packages/fluvie_cli/bin/fluvie.dart.
      final root = Directory.systemTemp.createTempSync('fluvie_root_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/${ProcessRenderLauncher.cliEntrypoint}').createSync(recursive: true);
      final deepAnchor = Directory('${root.path}/example/build/linux/x64/debug/bundle')
        ..createSync(recursive: true);

      final found = ProcessRenderLauncher.findWorkspaceRoot([deepAnchor]);

      expect(found.path, root.path);
      expect(File('${found.path}/${ProcessRenderLauncher.cliEntrypoint}').existsSync(), isTrue);
    });

    test('findWorkspaceRoot throws when no anchor reaches a checkout', () {
      final orphan = Directory.systemTemp.createTempSync('fluvie_orphan_');
      addTearDown(() => orphan.deleteSync(recursive: true));

      expect(
        () => ProcessRenderLauncher.findWorkspaceRoot([orphan]),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('readProgress parses "<done>/<total>" and tolerates absent/torn files', () {
      final dir = Directory.systemTemp.createTempSync('fluvie_progress_read_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/progress');

      // Absent file: nothing to report yet.
      expect(ProcessRenderLauncher.readProgress(file), isNull);

      // A complete line parses.
      file.writeAsStringSync('42/180');
      expect(
        ProcessRenderLauncher.readProgress(file),
        const RenderProgress(completed: 42, total: 180),
      );

      // A torn / malformed read is ignored (the next poll retries).
      file.writeAsStringSync('42/');
      expect(ProcessRenderLauncher.readProgress(file), isNull);
      file.writeAsStringSync('not-a-count');
      expect(ProcessRenderLauncher.readProgress(file), isNull);
    });
  });
}
