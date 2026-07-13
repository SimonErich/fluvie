import 'package:fluvie_presenter/src/speaker/speaker_window_launcher.dart';

/// The conditional-import fallback: no window opener on this platform.
SpeakerWindowLauncher createSpeakerLauncher() => const FallbackSpeakerLauncher();
