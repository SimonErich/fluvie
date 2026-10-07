import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';

const _captionStyle = CaptionStyle(
  textStyle: TextStyle(fontSize: 14, color: Colors.white),
  background: Color(0x80000000),
  highlight: Colors.white,
);

Video build() {
  return Video(
    size: VideoSize(160, 160),
    audio: [Audio.music('assets/music.wav', volume: 0.4, fadeIn: 500.ms, fadeOut: 500.ms)],
    captions: Captions.fromSrt('assets/captions.srt', style: _captionStyle),
    scenes: [
      Scene(
        duration: 2.5.seconds,
        background: Background.gradient(
          [Color(0xFF1A1A1A), Color(0xFF000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        children: [
          ElementId(
            id: 'title_text',
            child: Placed(
              placement: Placement(x: 0.5, y: 0.5),
              child: Text(
                'Milo and the Red Ball',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ).animate([Animation.fadeIn(duration: 0.8.seconds, delay: 0.3.seconds)]),
            ),
          ),
        ],
      ),
      Scene(
        duration: 3.5.seconds,
        background: Background.color(Color(0xFF1A1A1A)),
        children: [
          ElementId(
            id: 'milo_play_clip',
            child: Placed(
              placement: Placement(x: 0.5, y: 0.5, width: 0.9, height: 0.9),
              child: Clip.asset(
                'assets/play.mp4',
                fit: BoxFit.contain,
                audio: ClipAudio.muted(),
              ).animate([Animation.fadeIn(duration: 0.5.seconds)]),
            ),
          ),
          ElementId(
            id: 'red_ball_image',
            child: Placed(
              placement: Placement(x: 0.6, y: 0.6, width: 0.2, height: 0.2),
              child: Image.asset('assets/ball.png').animate([
                Animation.pop(duration: 0.4.seconds, delay: 0.2.seconds),
                Animation.drift(delay: 0.6.seconds),
              ]),
            ),
          ),
        ],
      ),
    ],
  );
}
