import 'package:desktop_studio/studio/studio_screen.dart';
import 'package:flutter/material.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// The desktop studio app shell.
class DesktopStudioApp extends StatelessWidget {
  /// Creates the app.
  const DesktopStudioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kitten Mitten Studio',
    debugShowCheckedModeBanner: false,
    theme: kittenAppTheme(),
    home: const StudioScreen(),
  );
}
