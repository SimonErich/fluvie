import 'package:flutter/widgets.dart';

/// Notes for the person presenting — never for the audience.
///
/// Drop one into a scene for that slide's default notes, or inside a `Stop`
/// to override while that step is active. It renders nothing and takes no
/// space on stage; the notes compiler collects it structurally and the notes
/// panel and speaker window read the compiled result.
///
/// ```dart
/// Scene(duration: 8.seconds, children: [
///   SpeakerNotes(
///     text: 'Open with the outage story.',
///     highlights: ['3am page', '14 services down', 'one line fix'],
///   ),
///   Text('Incident review'),
/// ]);
/// ```
///
/// The merge rule is simple: a step note's [text] replaces the scene text
/// when it has one, and its [highlights] append to the scene's. Several
/// notes in one scope merge in document order.
final class SpeakerNotes extends StatelessWidget {
  /// Creates notes with the full [text] and the glanceable [highlights].
  const SpeakerNotes({this.text, this.highlights = const [], super.key});

  /// What to say — the full prose, or `null` when only bullets matter here.
  final String? text;

  /// The quick-glance bullets the speaker view lists down its side.
  final List<String> highlights;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
