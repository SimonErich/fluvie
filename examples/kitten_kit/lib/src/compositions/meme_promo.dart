import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:kitten_kit/src/assets/kitten_assets.dart';
import 'package:kitten_kit/src/compositions/kitten_durations.dart';
import 'package:kitten_kit/src/painters/kitten_face_painter.dart';
import 'package:kitten_kit/src/theme/kitten_colors.dart';

const TextStyle _meme = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: 54,
  fontWeight: FontWeight.w800,
  height: 1.05,
);

/// Builds a square cat-meme clip.
///
/// A kitten scales in then floats ([Trigger.previous] chaining), bold top and
/// bottom captions slide in (the bottom after a short delay), and a corner clip
/// plays picture-in-picture. Designed to render fully in the browser.
Video memePromo({
  required String topText,
  required String bottomText,
  Color accent = KittenColors.mitten,
}) {
  return Video(
    size: VideoSize.square,
    poster: 1.seconds,
    audio: const <Audio>[Audio.music(KittenAssets.jingle, loop: true)],
    scenes: [
      Scene(
        duration: KittenDurations.meme,
        background: Background.gradient(const [Color(0xFF20141F), Color(0xFF3A1E3A)]),
        children: [
          Center(
            child:
                SizedBox(
                  width: 360,
                  height: 360,
                  child: CustomPaint(painter: KittenFacePainter(fur: accent)),
                ).animate([
                  Animation.scaleIn(),
                  Animation.float(at: Trigger.previous, amplitude: 0.06),
                ]),
          ),
          Positioned(
            top: 44,
            left: 24,
            right: 24,
            child: Text(
              topText.toUpperCase(),
              textAlign: TextAlign.center,
              style: _meme,
            ).animate([Animation.slideIn()]),
          ),
          Positioned(
            bottom: 44,
            left: 24,
            right: 24,
            child: Text(
              bottomText.toUpperCase(),
              textAlign: TextAlign.center,
              style: _meme,
            ).animate([Animation.slideIn(delay: 0.3.seconds)]),
          ),
          Align(
            alignment: const Alignment(0.94, 0.6),
            child: SizedBox(
              width: 150,
              height: 100,
              child: Clip.asset(
                KittenAssets.clip,
                fit: BoxFit.cover,
                // The kitten clip is silent; mute it so the audio mix does not
                // try to pull a track it does not have (the bed comes from music).
                audio: const ClipAudio.muted(),
              ).animate([Animation.fadeIn(delay: 0.5.seconds)]),
            ),
          ),
        ],
      ),
    ],
  );
}
