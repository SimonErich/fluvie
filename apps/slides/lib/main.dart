import 'package:flutter/widgets.dart';
import 'package:slides/routing/speaker_route.dart';
import 'package:slides/slides_app.dart';
import 'package:slides/speaker_app.dart';

void main() => runApp(isSpeakerRoute() ? const SpeakerApp() : const SlidesApp());
