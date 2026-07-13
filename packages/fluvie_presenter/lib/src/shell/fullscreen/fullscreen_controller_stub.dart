import 'package:fluvie_presenter/src/shell/fullscreen/fullscreen_controller.dart';

/// The conditional-import fallback: platforms that are neither web nor IO
/// get the no-op controller.
FullscreenController createFullscreenController() => const NoopFullscreenController();
