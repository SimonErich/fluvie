import 'package:flutter/widgets.dart';

/// A builder function that creates a media widget.
///
/// Used in template data classes where widgets cannot be stored directly
/// (since data classes should be const-constructible). The builder receives
/// a [BuildContext] and returns the widget to display.
///
/// Example usage:
/// ```dart
/// final MediaBuilder imageBuilder = (context) => Image.network(
///   'https://example.com/photo.jpg',
///   fit: BoxFit.cover,
/// );
/// ```
typedef MediaBuilder = Widget Function(BuildContext context);
