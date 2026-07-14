import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart' show collectMediaSources;
import 'package:fluvie_example/render/composition_entry.dart';

// The bundled fixtures the committed recap is built from — offline and
// deterministic, so the render is stable. Drop real photos and clips into
// `assets/days_recap/` and point [_days] at them to fill the recap with your
// own content.
const String _photo = 'assets/fixtures/swatch.png';
const String _clip = 'assets/fixtures/clip_1s.mp4';
const String _music = 'assets/audio/beat_loop.wav';

const Color _ink = Color(0xFFF3F5F7);
const Color _dim = Color(0xFFAEB8C2);

/// One tile of a day: a still photo or a video clip, both bundled assets.
sealed class _Media {
  const _Media(this.path);
  final String path;
}

final class _Photo extends _Media {
  const _Photo(super.path);
}

final class _MovingClip extends _Media {
  const _MovingClip(super.path);
}

/// One day of the recap: its number and date annotation, a caption, its
/// accent tint, and the photos and clips shot that day, grouped together.
final class _Day {
  const _Day({
    required this.number,
    required this.date,
    required this.caption,
    required this.tint,
    required this.media,
  });

  final int number;
  final String date;
  final String caption;
  final Color tint;
  final List<_Media> media;
}

/// A photo tile repeated [photos] times and a clip tile repeated [clips]
/// times — the fixture stand-in for a real day's mixed set.
List<_Media> _fixtureSet({required int photos, required int clips}) => [
  for (var i = 0; i < photos; i++) const _Photo(_photo),
  for (var i = 0; i < clips; i++) const _MovingClip(_clip),
];

const List<Color> _tints = [
  Color(0xFF11614F),
  Color(0xFF7A4A12),
  Color(0xFF3B2A6B),
  Color(0xFF124B63),
];

final List<_Day> _days = [
  _Day(
    number: 1,
    date: 'Saturday',
    caption: 'the slow morning',
    tint: _tints[0],
    media: _fixtureSet(photos: 4, clips: 2),
  ),
  _Day(
    number: 2,
    date: 'Sunday',
    caption: 'out and about',
    tint: _tints[1],
    media: _fixtureSet(photos: 3, clips: 2),
  ),
  _Day(
    number: 3,
    date: 'Monday',
    caption: 'back to it',
    tint: _tints[2],
    media: _fixtureSet(photos: 4, clips: 1),
  ),
  _Day(
    number: 4,
    date: 'Tuesday',
    caption: 'golden hour',
    tint: _tints[3],
    media: _fixtureSet(photos: 4, clips: 1),
  ),
];

/// A day-by-day photo-and-video recap: an intro card, one scene per day
/// (each annotated with its number and date, its photos and clips grouped
/// into a scattered collage), and an outro, over a looping music bed.
///
/// Data-driven off [_days], so every day renders through the one
/// [_daySection] builder and every tile through [_tile].
Video daysRecapVideo() => Video(
  width: 1280,
  height: 720,
  poster: const Time.seconds(1),
  audio: const [Audio.music(_music, loop: true, volume: 0.6, fadeOut: Time.seconds(1))],
  scenes: [
    _card('A Few Days', 'a little recap'),
    for (final day in _days) _daySection(day),
    _card("that's a wrap", 'made with fluvie', enter: true),
  ],
);

/// The intro/outro title card scene.
Scene _card(String title, String subtitle, {bool enter = false}) => Scene(
  duration: const Time.seconds(3),
  enter: enter ? const Transition.crossFade(Time.seconds(0.5)) : null,
  background: Background.gradient(const [Color(0xFF0B1E2A), Color(0xFF17384A)]),
  children: [TitleCard(title: title, subtitle: subtitle, reveal: const Time.seconds(0.6))],
);

/// One day's scene: the day annotation, the grouped collage of that day's
/// photos and clips, and a caption lower third.
Scene _daySection(_Day day) => Scene(
  duration: const Time.seconds(6),
  enter: const Transition.crossFade(Time.seconds(0.5)),
  background: Background.gradient([day.tint, const Color(0xFF0B1E2A)]),
  children: [
    Positioned(top: 48, left: 56, child: _dayLabel(day)),
    Align(alignment: const Alignment(0.12, 0.08), child: _collage(day.media)),
    LowerThird(
      name: day.caption,
      title: '${day.date} · Day ${day.number} · ${day.media.length} moments',
      reveal: const Time.seconds(0.5),
    ),
  ],
);

/// The day annotation: a big day number with a thin accent rule and the date
/// beneath, sliding in from the left.
Widget _dayLabel(_Day day) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'DAY ${day.number.toString().padLeft(2, '0')}',
      style: const TextStyle(color: _ink, fontSize: 60, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 8),
    const SizedBox(width: 110, height: 4, child: Box(color: _ink)),
    const SizedBox(height: 8),
    Text(day.date, style: const TextStyle(color: _dim, fontSize: 28)),
  ],
).animate([Animation.slideIn(from: Edge.left)]);

/// The day's media grouped into a scattered collage: a `Wrap` of card-framed,
/// slightly rotated tiles that stagger in, finished with a soft vignette.
Widget _collage(List<_Media> media) => SizedBox(
  width: 820,
  child:
      Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: [
          for (final (index, item) in media.indexed)
            Transform.rotate(angle: (index.isEven ? 1 : -1) * 0.03, child: _tile(item)),
        ],
      ).animate([
        Animation.slideFadeIn(stagger: const Stagger.each(Time.frames(2))),
        Animation.vignette(0.32),
      ]),
);

/// One collage tile: a framed photo, or a rounded video clip that plays.
Widget _tile(_Media item) => SizedBox(
  width: 210,
  height: 210,
  child: switch (item) {
    _Photo(:final path) => Image.asset(path, fit: BoxFit.cover, frame: const PhotoFrame.card()),
    _MovingClip(:final path) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Clip.asset(path, fit: BoxFit.cover),
    ),
  },
);

/// The renderable entry: `fluvie render days_recap`.
final daysRecapComposition = CompositionEntry(
  key: 'days_recap',
  width: 1280,
  height: 720,
  fps: 30,
  frameCount: daysRecapVideo().totalFrames,
  mediaSources: collectMediaSources(daysRecapVideo().scenes),
  build: () => Directionality(textDirection: TextDirection.ltr, child: daysRecapVideo()),
);
