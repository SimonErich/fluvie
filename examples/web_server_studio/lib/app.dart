import 'package:flutter/material.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:web_server_studio/submit/submit_screen.dart';

/// The server-render promo studio app shell.
class WebServerStudioApp extends StatelessWidget {
  /// Creates the app.
  const WebServerStudioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kitten Mitten Promo Studio',
    debugShowCheckedModeBanner: false,
    theme: kittenAppTheme(),
    home: const SubmitScreen(),
  );
}
