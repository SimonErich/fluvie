import 'package:fluvie_presenter/src/speaker/speaker_window_launcher.dart';
import 'package:web/web.dart' as web;

/// Creates the web launcher: a popup onto the speaker route.
SpeakerWindowLauncher createSpeakerLauncher() => const WebSpeakerLauncher();

// coverage:ignore-start browser bindings the VM coverage run never loads this library and the mapping onto window open is direct

/// Pops the speaker route open in a second browser window. Blocked popups
/// (or anything else the browser refuses) fall back to the URL instruction.
final class WebSpeakerLauncher implements SpeakerWindowLauncher {
  /// Creates the launcher.
  const WebSpeakerLauncher();

  /// The URL of the speaker route in this deployment.
  String get speakerUrl {
    final location = web.window.location;
    return '${location.origin}${location.pathname}#/speaker';
  }

  @override
  Future<SpeakerLaunchResult> open() async {
    final opened = web.window.open(speakerUrl, 'fluvie_speaker', 'popup=yes,width=960,height=640');
    return opened == null
        ? SpeakerLaunchResult.fallback(url: speakerUrl)
        : const SpeakerLaunchResult.opened();
  }
}

// coverage:ignore-end
