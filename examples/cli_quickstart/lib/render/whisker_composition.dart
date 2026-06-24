import 'package:fluvie/fluvie.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// The composition the CLI quickstart renders: the Kitten Mitten daily-standup
/// intro.
///
/// It uses animations and a `Trigger.previous` chain but no external media, so a
/// plain `fluvie render whisker_standup` works through the bundled, self-
/// contained capture harness with nothing else to set up.
Video whiskerStandup() => kittenPromo(
  headline: 'Whisker Daily Standup',
  tagline: 'Three things, then naps',
  withMusic: false,
);
