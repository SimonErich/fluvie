import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../example_base.dart';
import 'code_viewer_panel.dart';
import 'controls_panel.dart';
import 'preview_panel.dart';
import 'theme.dart';
import '../../utils/file_downloader.dart';
import 'package:fluvie/fluvie.dart';

/// Provider for selected example
final selectedShowcaseExampleProvider = StateProvider<InteractiveExample?>(
  (ref) => null,
);

/// Main showcase page with 3-panel layout
class ShowcasePage extends ConsumerStatefulWidget {
  final List<InteractiveExample> examples;

  const ShowcasePage({super.key, required this.examples});

  @override
  ConsumerState<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends ConsumerState<ShowcasePage> {
  final _boundaryKey = GlobalKey();
  bool _isRendering = false;
  String? _outputPath;
  int _renderProgress = 0;

  @override
  void initState() {
    super.initState();
    // Set first example as default and check for Impeller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.examples.isNotEmpty) {
        ref.read(selectedShowcaseExampleProvider.notifier).state =
            widget.examples.first;
      }
      // Show warning if Skia renderer is detected
      if (mounted) {
        ImpellerChecker.showWarningIfSkia(context);
      }
    });
  }

  Future<void> _renderVideo() async {
    final example = ref.read(selectedShowcaseExampleProvider);
    if (example == null) return;

    setState(() {
      _isRendering = true;
      _outputPath = null;
      _renderProgress = 0;
    });

    try {
      final renderService = ref.read(renderServiceProvider);

      // Build context from example
      final context = _findVideoCompositionContext();
      if (context == null) {
        throw Exception('Could not find video composition context');
      }

      final config = renderService.createConfigFromContext(context);

      final path = await renderService.execute(
        config: config,
        repaintBoundaryKey: _boundaryKey,
        onFrameUpdate: (frame) {
          setState(() {
            _renderProgress = frame;
          });
        },
      );

      if (mounted) {
        setState(() {
          _outputPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Render error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRendering = false;
        });
      }
    }
  }

  BuildContext? _findVideoCompositionContext() {
    final frameProviderContext = _boundaryKey.currentContext;
    if (frameProviderContext == null) return null;

    final element = frameProviderContext as Element;
    if (!element.mounted) return null;

    Element? compositionElement;

    void visit(Element e) {
      if (!e.mounted) return;
      if (e.widget is VideoComposition || e.widget is Video) {
        compositionElement = e;
        return;
      }
      e.visitChildren(visit);
    }

    visit(element);

    if (compositionElement == null) return null;

    BuildContext? childContext;
    compositionElement!.visitChildren((Element child) {
      if (childContext == null && child.mounted) {
        childContext = child;
      }
    });

    return childContext;
  }

  Future<void> _downloadVideo() async {
    if (_outputPath == null) return;

    try {
      await downloadFile(_outputPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video downloaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedExample = ref.watch(selectedShowcaseExampleProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine layout based on screen size
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    return Scaffold(
      drawer: _buildExampleDrawer(),
      body: Column(
        children: [
          _buildCustomAppBar(context, selectedExample),
          Expanded(
            child: isDesktop
                ? _buildDesktopLayout(selectedExample)
                : isTablet
                    ? _buildTabletLayout(selectedExample)
                    : _buildMobileLayout(selectedExample),
          ),
          if (_isRendering) _buildRenderProgress(),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(
    BuildContext context,
    InteractiveExample? selectedExample,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: GalleryTheme.backgroundGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Menu button
              Container(
                decoration: BoxDecoration(
                  gradient: GalleryTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: GalleryTheme.glowEffect(blurRadius: 15),
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Examples',
                ),
              ),
              const SizedBox(width: 16),
              // Title with gradient
              Expanded(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      GalleryTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    selectedExample?.title ?? 'Fluvie Interactive Gallery',
                    style: GalleryTheme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Action buttons
              if (_outputPath != null) ...[
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.download,
                  tooltip: 'Download video',
                  onPressed: _downloadVideo,
                  gradient: const LinearGradient(
                    colors: [GalleryTheme.success, Color(0xFF00A896)],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.video_library,
                tooltip: 'Render video',
                onPressed: _isRendering ? null : _renderVideo,
                gradient: GalleryTheme.accentGradient,
                isLoading: _isRendering,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required Gradient gradient,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? gradient : null,
        color: onPressed == null ? Colors.grey[800] : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.colors.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: IconButton(
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, color: Colors.white),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildDesktopLayout(InteractiveExample? example) {
    return Row(
      children: [
        // Controls panel (20%)
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.2,
          child: ControlsPanel(example: example),
        ),
        const VerticalDivider(width: 1),

        // Preview panel (50%)
        Expanded(
          flex: 5,
          child: PreviewPanel(
            example: example,
            repaintBoundaryKey: _boundaryKey,
          ),
        ),
        const VerticalDivider(width: 1),

        // Code/Instructions panel (30%)
        Expanded(flex: 3, child: CodeViewerPanel(example: example)),
      ],
    );
  }

  Widget _buildTabletLayout(InteractiveExample? example) {
    return Row(
      children: [
        // Preview + Code (controls in drawer)
        Expanded(
          flex: 6,
          child: PreviewPanel(
            example: example,
            repaintBoundaryKey: _boundaryKey,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(flex: 4, child: CodeViewerPanel(example: example)),
      ],
    );
  }

  Widget _buildMobileLayout(InteractiveExample? example) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.play_circle_outline), text: 'Preview'),
              Tab(icon: Icon(Icons.tune), text: 'Controls'),
              Tab(icon: Icon(Icons.code), text: 'Code'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                PreviewPanel(
                  example: example,
                  repaintBoundaryKey: _boundaryKey,
                ),
                ControlsPanel(example: example),
                CodeViewerPanel(example: example),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleDrawer() {
    // Group examples by category
    final examplesByCategory = <String, List<InteractiveExample>>{};
    for (final example in widget.examples) {
      examplesByCategory.putIfAbsent(example.category, () => []).add(example);
    }

    return Drawer(
      backgroundColor: GalleryTheme.deepBackground,
      child: Column(
        children: [
          // Custom header
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: GalleryTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: GalleryTheme.gradientStart.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fluvie Gallery',
                      style: GalleryTheme.textTheme.displayLarge?.copyWith(
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.examples.length} Interactive Examples',
                      style: GalleryTheme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Examples list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: examplesByCategory.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Text(
                        entry.key,
                        style: GalleryTheme.textTheme.titleLarge?.copyWith(
                          color: GalleryTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...entry.value.map((example) {
                      final isSelected =
                          ref.watch(selectedShowcaseExampleProvider)?.title ==
                              example.title;
                      return _buildExampleCard(example, isSelected);
                    }),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(InteractiveExample example, bool isSelected) {
    final difficultyColor = GalleryTheme.getDifficultyColor(example.difficulty);
    final difficultyIcon = GalleryTheme.getDifficultyIcon(example.difficulty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GalleryTheme.glassmorphicContainer(
        borderRadius: 12,
        backgroundColor: isSelected
            ? GalleryTheme.gradientStart.withValues(alpha: 0.15)
            : GalleryTheme.glassBackground,
        borderColor: isSelected
            ? GalleryTheme.gradientStart.withValues(alpha: 0.4)
            : GalleryTheme.glassBorder,
        padding: const EdgeInsets.all(16),
        blur: 8,
        child: InkWell(
          onTap: () {
            ref.read(selectedShowcaseExampleProvider.notifier).state = example;
            ref.read(previewFrameProvider.notifier).state = 0;
            ref.read(parameterValuesProvider.notifier).state = {};
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: difficultyColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(difficultyIcon, size: 14, color: difficultyColor),
                        const SizedBox(width: 6),
                        Text(
                          example.difficulty,
                          style: TextStyle(
                            color: difficultyColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                example.title,
                style: GalleryTheme.textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                example.description,
                style: GalleryTheme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRenderProgress() {
    final example = ref.read(selectedShowcaseExampleProvider);
    if (example == null) return const SizedBox.shrink();

    final maxFrames = example.getConfig().timeline.durationInFrames;
    final progress = _renderProgress / maxFrames;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: GalleryTheme.backgroundGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rendering Video...',
                style: GalleryTheme.textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GalleryTheme.textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  color: GalleryTheme.accentPink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: GalleryTheme.elevatedSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                GalleryTheme.accentPink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Frame $_renderProgress / $maxFrames',
            style: GalleryTheme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
