import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_presenter/src/speaker/speaker_launcher_stub.dart'
    if (dart.library.js_interop) 'package:fluvie_presenter/src/speaker/speaker_launcher_web.dart';
import 'package:meta/meta.dart';

/// How the speaker window opened — or how to open it yourself.
@immutable
final class SpeakerLaunchResult {
  /// A window opened; nothing else to do.
  const SpeakerLaunchResult.opened() : opened = true, url = null;

  /// No window could open: show [url] (when known) with an instruction to
  /// open it in a second window.
  const SpeakerLaunchResult.fallback({this.url}) : opened = false;

  /// Whether a window opened.
  final bool opened;

  /// The address to open manually, when the platform knows one.
  final String? url;

  @override
  bool operator ==(Object other) =>
      other is SpeakerLaunchResult && other.opened == opened && other.url == url;

  @override
  int get hashCode => Object.hash(SpeakerLaunchResult, opened, url);
}

/// Opens the speaker window for this platform.
///
/// The web launcher pops the speaker route open (browsers demand a user
/// gesture, which the S key handler is); a desktop shell overrides the
/// provider with its own multi-window launcher; everywhere else the
/// fallback tells the user what to open.
// A one-method contract on purpose: launchers differ per platform and apps
// override the provider with their own implementation.
// ignore: one_member_abstracts
abstract interface class SpeakerWindowLauncher {
  /// Tries to open the speaker window.
  Future<SpeakerLaunchResult> open();
}

/// The launcher for platforms that cannot open windows themselves: always
/// the fallback instruction.
final class FallbackSpeakerLauncher implements SpeakerWindowLauncher {
  /// Creates the fallback launcher.
  const FallbackSpeakerLauncher();

  @override
  Future<SpeakerLaunchResult> open() async => const SpeakerLaunchResult.fallback();
}

/// The platform's speaker-window launcher; apps override it to plug in a
/// desktop multi-window opener.
final speakerWindowLauncherProvider = Provider<SpeakerWindowLauncher>(
  (ref) => createSpeakerLauncher(),
);
