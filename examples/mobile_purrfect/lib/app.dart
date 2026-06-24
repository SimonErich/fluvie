import 'package:flutter/material.dart';
import 'package:kitten_kit/kitten_kit.dart';

import 'package:mobile_purrfect/compose/compose_screen.dart';

/// The on-device birthday-card app shell.
class MobilePurrfectApp extends StatelessWidget {
  /// Creates the app.
  const MobilePurrfectApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kitten Mitten',
    debugShowCheckedModeBanner: false,
    theme: kittenAppTheme(),
    home: const ComposeScreen(),
  );
}
