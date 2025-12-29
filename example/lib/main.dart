import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gallery/example_gallery.dart';
import 'gallery/showcase/showcase_page.dart';
import 'gallery/showcase/theme.dart';

void main() {
  // Handle Flutter framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    // Silently ignore MissingPluginException from just_audio on Linux
    if (details.exception is MissingPluginException) {
      final exception = details.exception as MissingPluginException;
      final message = exception.message ?? '';
      if (message.contains('just_audio') ||
          message.contains('com.ryanheise.just_audio')) {
        return; // Silently ignore
      }
    }
    // Log other errors in debug mode
    FlutterError.presentError(details);
  };

  // Handle platform errors (like MissingPluginException)
  PlatformDispatcher.instance.onError = (error, stack) {
    // Silently ignore MissingPluginException from just_audio
    if (error is MissingPluginException) {
      final message = error.message ?? '';
      if (message.contains('just_audio') ||
          message.contains('com.ryanheise.just_audio')) {
        return true; // Error handled, don't crash
      }
    }
    // Let other errors propagate
    return false;
  };

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluvie Interactive Gallery',
      debugShowCheckedModeBanner: false,
      theme: GalleryTheme.themeData,
      home: ShowcasePage(examples: allInteractiveExamples),
    );
  }
}
