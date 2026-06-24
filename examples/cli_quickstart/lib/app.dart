import 'package:cli_quickstart/preview/preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// The CLI quickstart preview app: a single screen that shows the composition
/// and the one command that renders it to an MP4.
class CliQuickstartApp extends StatelessWidget {
  /// Creates the quickstart app.
  const CliQuickstartApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kitten Mitten CLI Quickstart',
    debugShowCheckedModeBanner: false,
    theme: kittenAppTheme(),
    home: const PreviewScreen(),
  );
}
