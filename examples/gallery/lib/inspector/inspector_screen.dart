import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_example/inspector/generate_screen.dart';
import 'package:fluvie_example/inspector/inspector_panel.dart';
import 'package:fluvie_example/inspector/preview_pane.dart';
import 'package:fluvie_example/inspector/providers.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/playground/ai_assistant_panel.dart';
import 'package:fluvie_example/playground/playground.dart';
import 'package:fluvie_example/playground/playground_video.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';
import 'package:fluvie_example/theme/fluvie_gradients.dart';
import 'package:fluvie_example/theme/fluvie_theme.dart';
import 'package:fluvie_example/theme/widgets/film_stage.dart';
import 'package:fluvie_example/theme/widgets/gradient_text.dart';
import 'package:fluvie_example/theme/widgets/section_label.dart';

/// The inspector: the lesson list on the left, the video centre stage in the
/// middle, and the Code/Motions tabs on the right.
///
/// Each pane is its own consumer, so a lesson tap or a Playground render rebuilds
/// only what changed, through the selection and Playground providers.
final class InspectorScreen extends StatelessWidget {
  /// Creates the inspector screen.
  const InspectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: isMobile ? 4 : 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientText('Fluvie', style: Theme.of(context).textTheme.titleLarge),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              const Text(
                'inspector',
                style: TextStyle(
                  color: FluvieColors.dmut,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate with AI',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GenerateScreen()),
              ),
            ),
          ),
        ],
      ),
      // On a phone the three columns do not fit: the lesson list moves into a
      // drawer and the centre stage sits above the Code/Motions panel.
      drawer: isMobile
          ? Drawer(
              width: 300,
              child: Builder(
                builder: (context) =>
                    _LessonList(onItemTap: () => Scaffold.of(context).closeDrawer()),
              ),
            )
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: FluvieGradients.heroBackdrop),
        child: isMobile ? const _MobileBody() : const _DesktopBody(),
      ),
    );
  }
}

/// The wide layout: lesson list, centre stage, and the Code/Motions pane laid
/// out in three columns.
final class _DesktopBody extends StatelessWidget {
  const _DesktopBody();

  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: 260, child: _LessonList()),
      VerticalDivider(width: 1, color: FluvieColors.dline),
      Expanded(flex: 2, child: _CenterStage()),
      VerticalDivider(width: 1, color: FluvieColors.dline),
      Expanded(flex: 2, child: _RightPane()),
    ],
  );
}

/// The phone layout: a compact video header above the Code/Motions (or AI)
/// panel; the lesson list lives in the drawer.
///
/// The header is kept mounted while the keyboard is open (so the live
/// [PreviewPane] keeps resolving the lesson timeline) but takes no space, so the
/// editor gets the full height to type in.
final class _MobileBody extends StatelessWidget {
  const _MobileBody();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final videoHeight = (media.size.width * 9 / 16).clamp(150.0, media.size.height * 0.42);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Offstage(
          offstage: keyboardOpen,
          child: SizedBox(height: videoHeight, child: const _CenterStage()),
        ),
        const Expanded(child: _RightPane()),
      ],
    );
  }
}

/// The right pane: the AI Assistant, or a lesson's Code/Motions tabs.
final class _RightPane extends ConsumerWidget {
  const _RightPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workspaceModeProvider);
    return Material(
      color: FluvieColors.surface,
      child: switch (mode) {
        WorkspaceMode.aiAssistant => const AiAssistantPanel(),
        WorkspaceMode.lesson => const _LessonTabs(),
      },
    );
  }
}

/// A lesson's right pane: a Code tab hosting the [Playground] (the default) and
/// a Motions tab hosting the structured [InspectorPanel].
final class _LessonTabs extends StatelessWidget {
  const _LessonTabs();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Code', icon: Icon(Icons.code)),
              Tab(text: 'Motions', icon: Icon(Icons.movie_filter)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [Playground(), InspectorPanel()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The centre stage: the rendered video on a dark backdrop.
///
/// In AI Assistant mode it shows the generated video, or a placeholder before
/// the first render. In lesson mode it shows the freshly rendered Playground
/// video once one exists, otherwise the lesson's pre-rendered `/media/<key>.mp4`
/// (baked into the demo image, so no server render on load); the live
/// [PreviewPane] stays mounted behind the backdrop to resolve the lesson's
/// timeline for the Motions tab.
final class _CenterStage extends ConsumerWidget {
  const _CenterStage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workspaceModeProvider);
    final rendered = ref.watch(playgroundViewModelProvider.select((s) => s.videoUrl));
    if (mode == WorkspaceMode.aiAssistant) {
      final busy = ref.watch(
        playgroundViewModelProvider.select((s) => s.rendering || s.validating),
      );
      final Widget content;
      if (rendered != null) {
        content = PlaygroundVideo(url: rendered);
      } else if (busy) {
        content = const _AiRenderingState();
      } else {
        content = const _AiCenterPlaceholder();
      }
      return FilmStage(
        filename: rendered == null ? 'preview.mp4' : 'ai_video.mp4',
        child: content,
      );
    }
    final lessonKey = ref.watch(selectedLessonProvider).id;
    return Stack(
      fit: StackFit.expand,
      children: [
        const PreviewPane(),
        FilmStage(
          filename: '$lessonKey.mp4',
          child: PlaygroundVideo(url: rendered ?? '/media/$lessonKey.mp4'),
        ),
      ],
    );
  }
}

/// The centre stage while the AI Assistant's generated video is rendering.
final class _AiRenderingState extends StatelessWidget {
  const _AiRenderingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(color: FluvieColors.acc2),
        ),
        SizedBox(height: 16),
        Text('Rendering your video ...', style: TextStyle(color: FluvieColors.dtext)),
      ],
    ),
  );
}

/// The centre stage before the AI Assistant has rendered anything: a friendly
/// prompt to describe a video.
final class _AiCenterPlaceholder extends StatelessWidget {
  const _AiCenterPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.movie_filter_outlined, size: 48, color: FluvieColors.acc2),
        SizedBox(height: 16),
        Text('Your AI video will appear here', style: TextStyle(color: FluvieColors.dtext)),
        SizedBox(height: 4),
        Text(
          'Describe it on the right and press Generate.',
          style: TextStyle(color: FluvieColors.dmut, fontSize: 12),
        ),
      ],
    ),
  );
}

/// The left nav: the AI Assistant first, then the lessons in registry order.
/// Tapping an entry selects it and switches the workspace mode.
final class _LessonList extends ConsumerWidget {
  const _LessonList({this.onItemTap});

  /// Called after an entry is selected — closes the drawer on the phone layout.
  final VoidCallback? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workspaceModeProvider);
    final selected = ref.watch(selectedLessonIndexProvider);
    return Theme(
      data: buildFluvieDarkFrameTheme(),
      child: Material(
        color: FluvieColors.dpanel,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('AI Assistant'),
              subtitle: const Text(
                'Describe a video and generate it',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              selected: mode == WorkspaceMode.aiAssistant,
              onTap: () {
                ref.read(workspaceModeProvider.notifier).showAiAssistant();
                onItemTap?.call();
              },
            ),
            const Divider(height: 1, color: FluvieColors.dline),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SectionLabel('Lessons'),
            ),
            for (var index = 0; index < lessons.length; index++)
              ListTile(
                selected: mode == WorkspaceMode.lesson && index == selected,
                title: Text(lessons[index].title),
                subtitle: Text(lessons[index].intro, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  ref.read(selectedLessonIndexProvider.notifier).select(index);
                  ref.read(workspaceModeProvider.notifier).showLesson();
                  onItemTap?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}
