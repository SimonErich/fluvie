import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';
import 'package:kitten_kit/src/assets/kitten_assets.dart';
import 'package:kitten_kit/src/compositions/kitten_durations.dart';
import 'package:kitten_kit/src/painters/paw_print_painter.dart';
import 'package:kitten_kit/src/theme/kitten_colors.dart';

const TextStyle _title = TextStyle(
  color: KittenColors.ink,
  fontSize: 64,
  fontWeight: FontWeight.w800,
  height: 1.1,
);

/// Builds a birthday card video for a cat.
///
/// The title slides in then gently floats ([Trigger.previous] chaining), a
/// framed photo fades in and zooms (Ken Burns), and paw-print confetti pops in
/// one paw at a time. A music bed plays with a one-shot meow [Audio.sfx] on the
/// first frame.
///
/// Pass a [photo] (for example an `Image.memory` of a picked photo); when null a
/// committed `Image.asset` placeholder is used, which also demonstrates
/// `Image.asset`.
Video birthdayCard({
  required String catName,
  Image? photo,
  String song = KittenAssets.jingle,
}) {
  final framedPhoto =
      photo ??
      Image.asset(
        KittenAssets.photo,
        fit: BoxFit.cover,
        frame: const Frame.polaroid(caption: 'Birthday cat'),
      );
  return Video(
    size: VideoSize.square,
    poster: 2.seconds,
    audio: [
      Audio.music(song, fadeIn: const Time.seconds(0.4), fadeOut: const Time.seconds(0.6)),
      const Audio.sfx(KittenAssets.meowSfx, at: Trigger.sceneStart),
    ],
    scenes: [
      Scene(
        duration: KittenDurations.card,
        background: Background.gradient(const [Color(0xFFFFF0D9), Color(0xFFFFC9DE)]),
        children: [
          Positioned(
            top: 70,
            left: 24,
            right: 24,
            child:
                Text(
                  'Happy Birthday,\n$catName!',
                  textAlign: TextAlign.center,
                  style: _title,
                ).animate([
                  Animation.slideFade(),
                  Animation.float(at: Trigger.previous, amplitude: 0.05),
                ]),
          ),
          Center(
            child: SizedBox(
              width: 540,
              height: 540,
              child: framedPhoto.animate([Animation.fadeIn(), Animation.kenBurns()]),
            ),
          ),
          ..._pawConfetti(),
        ],
      ),
    ],
  );
}

List<Widget> _pawConfetti() {
  const spots = <Alignment>[
    Alignment(-0.8, 0.82),
    Alignment(-0.3, 0.9),
    Alignment(0.3, 0.9),
    Alignment(0.8, 0.82),
  ];
  return [
    for (int i = 0; i < spots.length; i++)
      Align(
        alignment: spots[i],
        child: const SizedBox(
          width: 70,
          height: 70,
          child: CustomPaint(painter: PawPrintPainter()),
        ).animate([Animation.pop(delay: Time.frames(6 * i))]),
      ),
  ];
}
