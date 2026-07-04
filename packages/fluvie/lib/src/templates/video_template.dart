import 'package:fluvie/src/composition/video.dart';

/// A parameterized, data-driven video definition: one [build] that turns a
/// `Props` value of type [P] into a [Video].
///
/// Subclass it to describe a video shape once and render it for many inputs —
/// the same definition produces a personalized intro per user, a stat reel per
/// metric, a release card per changelog entry. `build` is a pure function of its
/// [P]: it reads the props and returns a [Video], with no IO and no wall-clock,
/// so the same props always build the same tree. Combined with the frame-driven
/// capture pipeline, identical props render the same frames, so a batch caches
/// and goldens.
///
/// Render a template with the top-level `renderTemplate` free function, which
/// builds `template.build(props)` and runs the same offline capture shell as
/// `render(video, aspect:)`:
///
/// ```dart
/// final class IntroTemplate extends VideoTemplate<IntroProps> {
///   const IntroTemplate();
///   @override
///   Video build(IntroProps props) => Video(
///     size: VideoSize.reels,
///     scenes: [Scene.centered(duration: 3.seconds, child: Text(props.name))],
///   );
/// }
///
/// for (final user in users) {
///   await renderTemplate(const IntroTemplate(), props: IntroProps(name: user.name), ...);
/// }
/// ```
///
/// The built-in templates (`TitleIntro`, `StatHighlight`) extend this on the
/// public element API, so each is also a worked example of building a Video from
/// props.
// ignore: one_member_abstracts — the subclassing base, not an interface; templates extend it.
abstract class VideoTemplate<P> {
  /// Const so a template carries no state of its own — every choice flows
  /// through [build]'s [P], keeping the definition a pure function of its props.
  // coverage:ignore-line const super ctor artifact for the abstract template base
  const VideoTemplate();

  /// Builds the [Video] for [props].
  ///
  /// A pure function of [props]: no IO, no wall-clock, no unseeded randomness, so
  /// the same value always returns the same tree (so it caches and goldens).
  /// Override it to map your props onto scenes and elements.
  Video build(P props);
}
