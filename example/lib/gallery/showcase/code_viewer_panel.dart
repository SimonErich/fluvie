import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_syntax_view/flutter_syntax_view.dart';
import '../example_base.dart';
import 'theme.dart';

/// Provider to toggle between code and instructions view
final showInstructionsProvider = StateProvider<bool>((ref) => false);

/// Panel displaying source code and instructions
class CodeViewerPanel extends ConsumerWidget {
  final InteractiveExample? example;

  const CodeViewerPanel({super.key, this.example});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (example == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.code,
              size: 64,
              color: GalleryTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Select an example to view code',
              style: GalleryTheme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final showInstructions = ref.watch(showInstructionsProvider);

    return Container(
      color: GalleryTheme.surfaceBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom tab header
          Row(
            children: [
              Expanded(
                child: _buildCustomTabs(showInstructions, ref),
              ),
              const SizedBox(width: 8),
              if (!showInstructions)
                Container(
                  decoration: BoxDecoration(
                    gradient: GalleryTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: GalleryTheme.glowEffect(blurRadius: 8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                    tooltip: 'Copy code',
                    onPressed: () => _copyCode(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Content area
          Expanded(
            child: showInstructions
                ? _buildInstructions(context)
                : _buildCodeView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTabs(bool showInstructions, WidgetRef ref) {
    return Row(
      children: [
        _buildTab(
          icon: Icons.code,
          label: 'Code',
          isSelected: !showInstructions,
          onTap: () {
            ref.read(showInstructionsProvider.notifier).state = false;
          },
        ),
        const SizedBox(width: 12),
        _buildTab(
          icon: Icons.menu_book,
          label: 'Guide',
          isSelected: showInstructions,
          onTap: () {
            ref.read(showInstructionsProvider.notifier).state = true;
          },
        ),
      ],
    );
  }

  Widget _buildTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isSelected ? GalleryTheme.primaryGradient : null,
            color: isSelected ? null : GalleryTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : GalleryTheme.glassBorder,
              width: 1.5,
            ),
            boxShadow: isSelected ? GalleryTheme.glowEffect(blurRadius: 12) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GalleryTheme.textTheme.titleLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeView(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SyntaxView(
          code: example!.sourceCode,
          syntax: Syntax.DART,
          syntaxTheme: SyntaxTheme.vscodeDark(),
          fontSize: 13,
          withZoom: true,
          withLinesCount: true,
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    final instructions = example!.instructions;
    final difficultyColor = GalleryTheme.getDifficultyColor(example!.difficulty);

    return ListView.separated(
      itemCount: instructions.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header card
          return GalleryTheme.glassmorphicContainer(
            backgroundColor: GalleryTheme.elevatedSurface.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example!.title,
                  style: GalleryTheme.textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  example!.description,
                  style: GalleryTheme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: difficultyColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: difficultyColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            GalleryTheme.getDifficultyIcon(example!.difficulty),
                            size: 16,
                            color: difficultyColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            example!.difficulty,
                            style: TextStyle(
                              color: difficultyColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: GalleryTheme.gradientStart.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: GalleryTheme.gradientStart.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        example!.category,
                        style: const TextStyle(
                          color: GalleryTheme.gradientStart,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...example!.features.map((feature) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: GalleryTheme.glassBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: GalleryTheme.glassBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: GalleryTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
          );
        }

        // Instruction steps
        return GalleryTheme.glassmorphicContainer(
          backgroundColor: GalleryTheme.elevatedSurface.withValues(alpha: 0.2),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: GalleryTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: GalleryTheme.glowEffect(blurRadius: 8),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    instructions[index - 1],
                    style: GalleryTheme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: example!.sourceCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
