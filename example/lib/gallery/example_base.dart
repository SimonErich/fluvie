import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';
import 'models/example_parameter.dart';

/// Base class for all video examples
abstract class VideoExample {
  /// The title of the example
  String get title;

  /// Description of what the example demonstrates
  String get description;

  /// Features demonstrated in this example
  List<String> get features;

  /// Build the VideoComposition widget for this example
  Widget buildComposition();

  /// Get the RenderConfig for this example
  /// This extracts the config from the VideoComposition or Video widget
  RenderConfig getConfig() {
    final composition = buildComposition();
    if (composition is VideoComposition) {
      return composition.toConfig();
    }
    if (composition is Video) {
      return composition.toConfig();
    }
    // Fallback if not a VideoComposition or Video
    return RenderConfig(
      timeline: TimelineConfig(
        fps: 30,
        durationInFrames: 90,
        width: 1080,
        height: 1080,
      ),
      sequences: [],
    );
  }
}

/// Enhanced base class for interactive examples with parameter controls
abstract class InteractiveExample extends VideoExample {
  /// Difficulty level: "Beginner", "Intermediate", or "Advanced"
  String get difficulty;

  /// Category: "Getting Started", "Text & Typography", etc.
  String get category;

  /// List of adjustable parameters for this example
  List<ExampleParameter> get parameters;

  /// Full source code for display in code viewer
  String get sourceCode;

  /// Step-by-step instructions explaining the example
  List<String> get instructions;

  /// Build the composition with custom parameter values
  Widget buildWithParameters(Map<String, dynamic> parameterValues);

  /// Get default values for all parameters
  Map<String, dynamic> get defaultParameters {
    return Map.fromEntries(
      parameters.map((p) => MapEntry(p.id, p.defaultValue)),
    );
  }

  /// Override buildComposition to use default parameters
  @override
  Widget buildComposition() {
    return buildWithParameters(defaultParameters);
  }
}
