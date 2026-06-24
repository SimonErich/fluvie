import 'package:fluvie/fluvie.dart';

/// One gallery lesson: a short intro, one complete readable [Video], and the
/// id the render registry and the CLI know it by.
///
/// Lessons are pure descriptions — [video] builds a fresh composition on
/// every call, so the inspector, the goldens, and the capture harness each
/// mount their own tree. The poster frame lives on the `Video` itself
/// (`video().poster`); the model carries no duplicate.
final class Lesson {
  /// Creates a lesson; every field is required by design — a lesson without
  /// an intro or a video is not a lesson.
  const Lesson({
    required this.id,
    required this.title,
    required this.intro,
    required this.video,
  });

  /// The stable key (`01_hello_video`) used by the render registry, the CLI,
  /// and the golden file names.
  final String id;

  /// The human title shown in the gallery list.
  final String title;

  /// One or two sentences saying what the lesson teaches.
  final String intro;

  /// Builds the lesson's composition — a fresh [Video] per call.
  final Video Function() video;
}
