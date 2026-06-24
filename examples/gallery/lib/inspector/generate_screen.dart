import 'package:flutter/material.dart';
import 'package:fluvie_example/inspector/generate_panel.dart';
import 'package:fluvie_example/theme/fluvie_colors.dart';

/// A full screen hosting the "Generate with AI" panel, pushed from the
/// inspector's app bar.
final class GenerateScreen extends StatelessWidget {
  /// Creates the screen.
  const GenerateScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FluvieColors.surface,
    appBar: AppBar(title: const Text('Generate with AI')),
    body: const GeneratePanel(),
  );
}
