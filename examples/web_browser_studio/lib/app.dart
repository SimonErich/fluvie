import 'package:flutter/material.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:web_browser_studio/maker/maker_screen.dart';

/// The in-browser meme maker app shell.
class WebBrowserStudioApp extends StatelessWidget {
  /// Creates the app.
  const WebBrowserStudioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kitten Mitten Meme Maker',
    debugShowCheckedModeBanner: false,
    theme: kittenAppTheme(),
    home: const MakerScreen(),
  );
}
