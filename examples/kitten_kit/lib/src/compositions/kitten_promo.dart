import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:kitten_kit/src/assets/kitten_assets.dart';
import 'package:kitten_kit/src/compositions/kitten_durations.dart';
import 'package:kitten_kit/src/painters/kitten_face_painter.dart';
import 'package:kitten_kit/src/theme/kitten_colors.dart';

const TextStyle _headline = TextStyle(
  color: KittenColors.ink,
  fontSize: 72,
  fontWeight: FontWeight.w800,
  height: 1.05,
);
const TextStyle _tagline = TextStyle(
  color: KittenColors.mittenDeep,
  fontSize: 32,
  fontWeight: FontWeight.w600,
);
const TextStyle _feature = TextStyle(
  color: KittenColors.ink,
  fontSize: 30,
  fontWeight: FontWeight.w500,
);

const List<String> _features = <String>[
  'Tiny mittens, big comfort',
  'Ethically sourced yarn',
  'Purr-approved fit',
];

/// Builds the Kitten Mitten promo: a landscape product spot.
///
/// A hand-drawn kitten scales in then keeps floating ([Trigger.previous]
/// chaining), the headline slides in, the optional tagline fades in after it,
/// and three feature lines stagger in. Pass [withMusic] for a looping jingle and
/// [withClip] for a corner picture-in-picture clip.
Video kittenPromo({
  required String headline,
  String? tagline,
  Color fur = KittenColors.tabby,
  bool withMusic = true,
  bool withClip = false,
}) {
  return Video(
    size: VideoSize.hd,
    poster: 1.seconds,
    audio: withMusic
        ? const <Audio>[
            Audio.music(
              KittenAssets.jingle,
              loop: true,
              fadeIn: Time.seconds(0.4),
              fadeOut: Time.seconds(0.6),
            ),
          ]
        : const <Audio>[],
    scenes: [
      Scene(
        duration: KittenDurations.promo,
        background: Background.gradient(const [Color(0xFFFFE3D0), Color(0xFFFFB7C9)]),
        children: [
          Align(
            alignment: const Alignment(-0.62, 0.05),
            child:
                SizedBox(
                  width: 300,
                  height: 300,
                  child: CustomPaint(painter: KittenFacePainter(fur: fur)),
                ).animate([
                  Animation.scaleIn(),
                  Animation.float(at: Trigger.previous, amplitude: 0.08),
                ]),
          ),
          Align(
            alignment: const Alignment(0.5, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Text(headline, style: _headline).animate([Animation.slideIn()]),
                if (tagline != null)
                  Text(tagline, style: _tagline).animate([Animation.fadeIn(delay: 0.25.seconds)]),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [for (final String f in _features) Text('•  $f', style: _feature)],
                ).animate([Animation.slideFadeIn(stagger: const Stagger.each(Time.frames(7)))]),
              ],
            ),
          ),
          if (withClip)
            Align(
              alignment: const Alignment(0.92, -0.84),
              child: SizedBox(
                width: 220,
                height: 130,
                child: Clip.asset(
                  KittenAssets.clip,
                  fit: BoxFit.cover,
                ).animate([Animation.fadeIn(delay: 0.4.seconds)]),
              ),
            ),
        ],
      ),
    ],
  );
}
