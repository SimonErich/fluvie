// WI-22 (§15, decision D-Annotations): the child-wrapping annotation goldens.
// Each mounts the real widget through the golden frame clock at a representative
// frame. `spotlight_focus` dims a colored background with the lit region open;
// `lower_third` freezes the name/title bar mid slide-in (frame 5 of a 10-frame
// slide); `title_card` shows the title revealed. Backgrounds are colored boxes
// and text renders in Ahem in the CI goldens, so the files stay byte-stable.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart' show Tags;
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/lower_third.dart';
import 'package:fluvie/src/elements/annotations/spotlight.dart';
import 'package:fluvie/src/elements/annotations/title_card.dart';

import '../../animation/helpers/golden_frame.dart';

const Size _wide = Size(320, 180);

Widget _spotlight() => const Spotlight.on(
  region: Rect.fromLTWH(180, 50, 100, 80),
  child: ColoredBox(color: Color(0xFF2E5AAC)),
);

Widget _lowerThird() => const ColoredBox(
  color: Color(0xFF2E5AAC),
  child: LowerThird(name: 'Ada Lovelace', title: 'Mathematician', reveal: Time.frames(10)),
);

Widget _titleCard() => const ColoredBox(
  color: Color(0xFF1B1F24),
  child: TitleCard(title: 'Chapter One', subtitle: 'The beginning'),
);

Future<void> main() async {
  await goldenMotionFrames(
    description: 'Spotlight dims the canvas but the lit region',
    fileName: 'spotlight_focus',
    frames: const [30],
    subject: _spotlight,
    size: _wide,
  );
  await goldenMotionFrames(
    description: 'LowerThird slides its name/title bar in from the left',
    fileName: 'lower_third',
    frames: const [5],
    subject: _lowerThird,
    size: _wide,
  );
  await goldenMotionFrames(
    description: 'TitleCard centers a revealed title and subtitle',
    fileName: 'title_card',
    frames: const [60],
    subject: _titleCard,
    size: const Size(360, 260),
  );
}
