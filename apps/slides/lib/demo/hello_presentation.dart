import 'package:flutter/widgets.dart' hide Animation;
import 'package:fluvie/fluvie.dart';

/// The Phase 1 demo deck: one scene, played live end to end.
///
/// It exists so the app has something to present before the real example
/// presentations land in Phase 7, and so the fluvie live player is exercised
/// by a running app from day one.
Video helloPresentation() => Video(
  size: VideoSize.hd,
  scenes: [
    Scene(
      duration: const Time.seconds(6),
      background: Background.color(const Color(0xFF14141C)),
      children: [
        const Text(
          'fluvie slides',
          style: TextStyle(color: Color(0xFFF2F2F7), fontSize: 96),
        ).animate([
          Animation.fadeIn(duration: const Time.seconds(0.6)),
          Animation.float(),
        ]),
        Align(
          alignment: const Alignment(0, 0.35),
          child:
              const Text(
                'a Video, presented live',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 40),
              ).animate([
                Animation.fadeIn(delay: const Time.seconds(0.4), duration: const Time.seconds(0.6)),
              ]),
        ),
      ],
    ),
  ],
);
