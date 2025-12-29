import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../presentation/time_consumer.dart';
import '../../declarative/animations/core/animated_prop.dart';
import '../../declarative/animations/core/prop_animation.dart';
import '../_base/template_base.dart';
import '../_base/template_config.dart';
import '../_base/template_data.dart';

/// Scrolling receipt listing all songs/achievements.
///
/// Creates a nostalgic receipt-style summary that scrolls through
/// all the items, stats, and achievements. Perfect for comprehensive
/// year-end summaries.
///
/// Best used for:
/// - Detailed summaries
/// - Song lists
/// - Achievement lists
///
/// Example:
/// ```dart
/// WrappedReceipt(
///   data: SummaryData(
///     title: 'Your Receipt',
///     items: ['Song 1', 'Song 2', ...],
///     stats: {'Total': '\$1,234'},
///   ),
/// )
/// ```
class WrappedReceipt extends WrappedTemplate with TemplateAnimationMixin {
  /// Items to list on the receipt.
  final List<ReceiptItem>? items;

  /// Whether to show thermal paper texture.
  final bool showTexture;

  /// Scroll speed multiplier.
  final double scrollSpeed;

  const WrappedReceipt({
    super.key,
    required SummaryData super.data,
    super.theme,
    super.timing,
    this.items,
    this.showTexture = true,
    this.scrollSpeed = 1.0,
  });

  @override
  int get recommendedLength => 250;

  @override
  TemplateCategory get category => TemplateCategory.conclusion;

  @override
  String get description => 'Scrolling receipt with all achievements';

  @override
  TemplateTheme get defaultTheme => TemplateTheme.minimal;

  SummaryData get summaryData => data as SummaryData;

  List<ReceiptItem> get effectiveItems {
    if (items != null) return items!;

    // Generate from stats
    return summaryData.stats.entries.map((e) {
      return ReceiptItem(label: e.key, value: '${e.value}');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = effectiveTheme;

    return Container(
      color: colors.backgroundColor,
      child: Center(child: _buildReceipt(colors)),
    );
  }

  Widget _buildReceipt(TemplateTheme colors) {
    return TimeConsumer(
      builder: (context, frame, _) {
        // Entry animation
        final entryProgress = ((frame - 20) / 40).clamp(0.0, 1.0);
        final entryScale = Curves.easeOutBack.transform(entryProgress);

        return Transform.scale(
          scale: entryScale,
          child: Opacity(
            opacity: entryProgress,
            child: Container(
              width: 400,
              constraints: BoxConstraints(maxHeight: 700),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF0), // Thermal paper color
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Paper texture
                  if (showTexture)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ReceiptTexturePainter(),
                        size: Size.infinite,
                      ),
                    ),

                  // Receipt content
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildReceiptContent(colors, frame),
                    ),
                  ),

                  // Torn edge at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: CustomPaint(
                      painter: _TornEdgePainter(),
                      size: const Size(double.infinity, 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptContent(TemplateTheme colors, int frame) {
    const receiptTextColor = Color(0xFF333333);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        _buildReceiptHeader(receiptTextColor, frame),

        const SizedBox(height: 24),

        // Divider
        _buildDottedDivider(receiptTextColor),

        const SizedBox(height: 16),

        // Title
        AnimatedProp(
          startFrame: 60,
          duration: 30,
          animation: PropAnimation.fadeIn(),
          child: Text(
            summaryData.title ?? 'YOUR WRAPPED RECEIPT',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: receiptTextColor,
              fontFamily: 'monospace',
            ),
          ),
        ),

        const SizedBox(height: 16),

        _buildDottedDivider(receiptTextColor),

        const SizedBox(height: 16),

        // Items
        ...effectiveItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return AnimatedProp(
            startFrame: 80 + index * 5,
            duration: 20,
            animation: PropAnimation.fadeIn(),
            child: _buildReceiptItem(item, receiptTextColor),
          );
        }),

        const SizedBox(height: 16),

        _buildDottedDivider(receiptTextColor),

        const SizedBox(height: 16),

        // Summary totals
        ..._buildSummarySection(receiptTextColor, frame),

        const SizedBox(height: 24),

        _buildDottedDivider(receiptTextColor),

        const SizedBox(height: 16),

        // Footer
        _buildReceiptFooter(receiptTextColor, frame),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildReceiptHeader(Color textColor, int frame) {
    return AnimatedProp(
      startFrame: 40,
      duration: 30,
      animation: PropAnimation.fadeIn(),
      child: Column(
        children: [
          Text(
            '* * * * * * * * * * *',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summaryData.name ?? 'CUSTOMER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'WRAPPED ${summaryData.year ?? DateTime.now().year}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.7),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedDivider(Color color) {
    return Row(
      children: List.generate(
        40,
        (index) => Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            color: index.isEven
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptItem(ReceiptItem item, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              item.label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSummarySection(Color textColor, int frame) {
    final summaryItems = <Widget>[];

    // Sub-total
    summaryItems.add(
      AnimatedProp(
        startFrame: 150,
        duration: 20,
        animation: PropAnimation.fadeIn(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SUBTOTAL',
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '${effectiveItems.length} ITEMS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );

    summaryItems.add(const SizedBox(height: 8));

    // Total
    summaryItems.add(
      AnimatedProp(
        startFrame: 170,
        duration: 25,
        animation: PropAnimation.fadeIn(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOTAL VIBES',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              '100%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );

    return summaryItems;
  }

  Widget _buildReceiptFooter(Color textColor, int frame) {
    return AnimatedProp(
      startFrame: 200,
      duration: 30,
      animation: PropAnimation.fadeIn(),
      child: Column(
        children: [
          Text(
            'THANK YOU FOR LISTENING!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summaryData.subtitle ?? 'SEE YOU NEXT YEAR',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.7),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          // Barcode simulation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(30, (index) {
              final width = (index % 3 == 0) ? 3.0 : 1.5;
              return Container(
                width: width,
                height: 40,
                color: textColor,
                margin: const EdgeInsets.symmetric(horizontal: 1),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Item on the receipt.
class ReceiptItem {
  final String label;
  final String value;
  final String? subtitle;

  const ReceiptItem({required this.label, required this.value, this.subtitle});
}

class _ReceiptTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()
      ..color = const Color(0xFFE8E4D4).withValues(alpha: 0.3);

    // Subtle speckles
    for (var i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }

    // Horizontal lines (thermal printer effect)
    for (var y = 0.0; y < size.height; y += 2) {
      if (random.nextDouble() > 0.95) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()..color = const Color(0xFFDDD8C8).withValues(alpha: 0.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TornEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFDF0);
    final path = Path();

    path.moveTo(0, size.height);

    // Create torn edge effect
    var x = 0.0;
    final random = math.Random(42);
    while (x < size.width) {
      final peakHeight = random.nextDouble() * 8 + 2;
      path.lineTo(x, size.height - peakHeight);
      x += random.nextDouble() * 8 + 4;
      path.lineTo(x, size.height);
      x += random.nextDouble() * 8 + 4;
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
