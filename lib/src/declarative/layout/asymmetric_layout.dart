import 'package:flutter/material.dart';

/// A collection of pre-designed asymmetric photo layout templates.
///
/// These layouts create visually interesting arrangements of photos
/// that break away from traditional grid patterns.
///
/// Example:
/// ```dart
/// AsymmetricLayout.heroLeft(
///   hero: PhotoCard(assetPath: 'main.jpg', width: 500, height: 400),
///   secondary: [
///     PhotoCard(assetPath: 'small1.jpg', width: 240, height: 190),
///     PhotoCard(assetPath: 'small2.jpg', width: 240, height: 190),
///   ],
///   spacing: 20,
/// )
/// ```
class AsymmetricLayout extends StatelessWidget {
  final Widget child;

  const AsymmetricLayout._({required this.child});

  /// Creates a layout with a large hero image on the left
  /// and smaller images stacked on the right.
  ///
  /// Perfect for highlighting one main photo with supporting images.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.heroLeft(
  ///   hero: PhotoCard(assetPath: 'hero.jpg', width: 500, height: 400),
  ///   secondary: [
  ///     PhotoCard(assetPath: 'small1.jpg', width: 240, height: 190),
  ///     PhotoCard(assetPath: 'small2.jpg', width: 240, height: 190),
  ///   ],
  /// )
  /// ```
  factory AsymmetricLayout.heroLeft({
    Key? key,
    required Widget hero,
    required List<Widget> secondary,
    double spacing = 16,
    CrossAxisAlignment verticalAlignment = CrossAxisAlignment.center,
  }) {
    return AsymmetricLayout._(
      child: Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: verticalAlignment,
        children: [
          hero,
          SizedBox(width: spacing),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < secondary.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                secondary[i],
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Creates a layout with a large hero image on the right
  /// and smaller images stacked on the left.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.heroRight(
  ///   hero: PhotoCard(assetPath: 'hero.jpg', width: 500, height: 400),
  ///   secondary: [
  ///     PhotoCard(assetPath: 'small1.jpg', width: 240, height: 190),
  ///     PhotoCard(assetPath: 'small2.jpg', width: 240, height: 190),
  ///   ],
  /// )
  /// ```
  factory AsymmetricLayout.heroRight({
    Key? key,
    required Widget hero,
    required List<Widget> secondary,
    double spacing = 16,
    CrossAxisAlignment verticalAlignment = CrossAxisAlignment.center,
  }) {
    return AsymmetricLayout._(
      child: Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: verticalAlignment,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < secondary.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                secondary[i],
              ],
            ],
          ),
          SizedBox(width: spacing),
          hero,
        ],
      ),
    );
  }

  /// Creates a scattered/magazine-style layout with overlapping photos.
  ///
  /// Photos are positioned with slight offsets and rotations to create
  /// a dynamic, casual arrangement.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.scattered(
  ///   photos: [
  ///     PhotoCard(assetPath: 'photo1.jpg', width: 300, height: 200),
  ///     PhotoCard(assetPath: 'photo2.jpg', width: 280, height: 220),
  ///     PhotoCard(assetPath: 'photo3.jpg', width: 260, height: 180),
  ///   ],
  ///   baseOffset: Offset(100, 80),
  ///   rotations: [-0.05, 0.03, -0.02],
  /// )
  /// ```
  factory AsymmetricLayout.scattered({
    Key? key,
    required List<Widget> photos,
    required Size containerSize,
    List<Offset>? positions,
    List<double>? rotations,
    Offset baseOffset = const Offset(120, 100),
  }) {
    // Default positions create a scattered look
    final defaultPositions = <Offset>[
      Offset.zero,
      Offset(baseOffset.dx * 1.2, baseOffset.dy * 0.3),
      Offset(baseOffset.dx * 0.4, baseOffset.dy * 1.4),
      Offset(baseOffset.dx * 1.8, baseOffset.dy * 1.1),
      Offset(baseOffset.dx * 0.8, baseOffset.dy * 0.6),
      Offset(baseOffset.dx * 2.2, baseOffset.dy * 0.2),
    ];

    // Default rotations for natural look
    final defaultRotations = <double>[-0.04, 0.03, -0.02, 0.05, -0.03, 0.02];

    final effectivePositions = positions ?? defaultPositions;
    final effectiveRotations = rotations ?? defaultRotations;

    return AsymmetricLayout._(
      child: SizedBox(
        key: key,
        width: containerSize.width,
        height: containerSize.height,
        child: Stack(
          children: [
            for (int i = 0; i < photos.length; i++)
              Positioned(
                left: i < effectivePositions.length
                    ? effectivePositions[i].dx
                    : 0,
                top: i < effectivePositions.length
                    ? effectivePositions[i].dy
                    : 0,
                child: Transform.rotate(
                  angle:
                      i < effectiveRotations.length ? effectiveRotations[i] : 0,
                  child: photos[i],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Creates a diagonal cascade layout where photos are arranged
  /// in a stepping pattern.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.cascade(
  ///   photos: [photo1, photo2, photo3],
  ///   offsetStep: Offset(80, 60),
  ///   rotationStep: 0.02,
  /// )
  /// ```
  factory AsymmetricLayout.cascade({
    Key? key,
    required List<Widget> photos,
    required Size containerSize,
    Offset offsetStep = const Offset(100, 70),
    double rotationStep = 0.015,
    bool alternateRotation = true,
  }) {
    return AsymmetricLayout._(
      child: SizedBox(
        key: key,
        width: containerSize.width,
        height: containerSize.height,
        child: Stack(
          children: [
            for (int i = 0; i < photos.length; i++)
              Positioned(
                left: offsetStep.dx * i,
                top: offsetStep.dy * i,
                child: Transform.rotate(
                  angle: alternateRotation
                      ? (i.isEven ? rotationStep : -rotationStep)
                      : rotationStep * i,
                  child: photos[i],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Creates a masonry-style layout with photos in columns of varying heights.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.masonry(
  ///   photos: [photo1, photo2, photo3, photo4],
  ///   columns: 2,
  ///   spacing: 16,
  /// )
  /// ```
  factory AsymmetricLayout.masonry({
    Key? key,
    required List<Widget> photos,
    int columns = 2,
    double spacing = 16,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    // Distribute photos across columns
    final columnWidgets = List.generate(columns, (_) => <Widget>[]);
    for (int i = 0; i < photos.length; i++) {
      columnWidgets[i % columns].add(photos[i]);
    }

    return AsymmetricLayout._(
      child: Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          for (int col = 0; col < columns; col++) ...[
            if (col > 0) SizedBox(width: spacing),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < columnWidgets[col].length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  columnWidgets[col][i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Creates a featured layout with one large photo and a strip of smaller ones below.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.featuredWithStrip(
  ///   featured: PhotoCard(assetPath: 'main.jpg', width: 800, height: 400),
  ///   strip: [smallPhoto1, smallPhoto2, smallPhoto3],
  ///   spacing: 16,
  /// )
  /// ```
  factory AsymmetricLayout.featuredWithStrip({
    Key? key,
    required Widget featured,
    required List<Widget> strip,
    double spacing = 16,
    MainAxisAlignment stripAlignment = MainAxisAlignment.center,
  }) {
    return AsymmetricLayout._(
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          featured,
          SizedBox(height: spacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: stripAlignment,
            children: [
              for (int i = 0; i < strip.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                strip[i],
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Creates a T-shaped layout with photos arranged in a T pattern.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.tShape(
  ///   topRow: [photo1, photo2, photo3],
  ///   bottom: largePhoto,
  ///   spacing: 16,
  /// )
  /// ```
  factory AsymmetricLayout.tShape({
    Key? key,
    required List<Widget> topRow,
    required Widget bottom,
    double spacing = 16,
  }) {
    return AsymmetricLayout._(
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < topRow.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                topRow[i],
              ],
            ],
          ),
          SizedBox(height: spacing),
          bottom,
        ],
      ),
    );
  }

  /// Creates a polaroid stack effect with photos slightly offset and rotated.
  ///
  /// Example:
  /// ```dart
  /// AsymmetricLayout.polaroidStack(
  ///   photos: [photo1, photo2, photo3],
  ///   containerSize: Size(600, 500),
  ///   spreadAngle: 0.15,
  /// )
  /// ```
  factory AsymmetricLayout.polaroidStack({
    Key? key,
    required List<Widget> photos,
    required Size containerSize,
    double spreadAngle = 0.12,
    Offset centerOffset = Offset.zero,
  }) {
    final count = photos.length;
    final halfCount = (count - 1) / 2;

    return AsymmetricLayout._(
      child: SizedBox(
        key: key,
        width: containerSize.width,
        height: containerSize.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < count; i++)
              Transform.translate(
                offset: centerOffset,
                child: Transform.rotate(
                  angle: (i - halfCount) * spreadAngle,
                  child: photos[i],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => child;
}
