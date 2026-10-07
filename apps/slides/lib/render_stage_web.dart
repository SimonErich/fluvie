import 'package:flutter/widgets.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart' show FluvieWebStage;

// coverage:ignore-start browser only root wrapper the stage drives the live
// engine pipeline which the unit test binding cannot

/// The web arm: mounts the off-screen `FluvieWebStage` capture surface the
/// in-browser video export renders through.
Widget wrapWithRenderStage(Widget app) => FluvieWebStage(child: app);

// coverage:ignore-end
