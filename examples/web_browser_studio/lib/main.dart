import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

import 'package:web_browser_studio/app.dart';

// FluvieWebStage gives in-browser rendering an off-screen capture surface inside
// the app's own pipeline; WebVideoRenderer captures through it by default.
void main() => runApp(
  const FluvieWebStage(child: ProviderScope(child: WebBrowserStudioApp())),
);
