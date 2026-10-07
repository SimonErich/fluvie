import 'package:flutter/widgets.dart';
import 'package:slides/render_stage.dart';
import 'package:slides/routing/speaker_route.dart';
import 'package:slides/slides_app.dart';
import 'package:slides/speaker_app.dart';

void main() => runApp(
  // The speaker popup never exports video, so only the main window carries
  // the (web-only) off-screen capture stage.
  isSpeakerRoute() ? const SpeakerApp() : wrapWithRenderStage(const SlidesApp()),
);
