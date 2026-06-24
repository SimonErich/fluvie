import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_example/inspector/inspector_screen.dart';
import 'package:fluvie_example/theme/fluvie_theme.dart';

void main() => runApp(const FluvieExampleApp());

/// The Fluvie example app: the lessons inside the inspector shell.
///
/// The root mounts the Riverpod [ProviderScope], applies the Fluvie brand theme,
/// and binds the AI client to the environment-configured provider
/// (`FLUVIE_AI_PROVIDER` + API keys), so the "Generate with AI" panel works
/// without further wiring. The inspector screen owns the lesson list, the AI
/// Assistant, the video stage, and the Code/Motions tabs.
class FluvieExampleApp extends StatelessWidget {
  /// Creates the app shell.
  const FluvieExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        aiClientProvider.overrideWith((ref) => aiClientFromEnv(Platform.environment)),
      ],
      child: MaterialApp(
        title: 'Fluvie lessons',
        theme: buildFluvieTheme(),
        home: const InspectorScreen(),
      ),
    );
  }
}
