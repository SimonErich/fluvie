import 'package:fluvie_example/lessons/01_hello_video.dart';
import 'package:fluvie_example/lessons/02_text_and_motion.dart';
import 'package:fluvie_example/lessons/03_timing_and_triggers.dart';
import 'package:fluvie_example/lessons/04_scenes_and_transitions.dart';
import 'package:fluvie_example/lessons/05_images_and_clips.dart';
import 'package:fluvie_example/lessons/06_collage.dart';
import 'package:fluvie_example/lessons/07_charts.dart';
import 'package:fluvie_example/lessons/08_code_doc_intro.dart';
import 'package:fluvie_example/lessons/09_diagrams_and_webviews.dart';
import 'package:fluvie_example/lessons/10_audio_and_captions.dart';
import 'package:fluvie_example/lessons/11_templates_and_aspects.dart';
import 'package:fluvie_example/lessons/12_the_kitchen_sink.dart';
import 'package:fluvie_example/lessons/13_generative_content.dart';
import 'package:fluvie_example/lessons/lesson.dart';

export 'package:fluvie_example/lessons/lesson.dart';

/// Every lesson, in gallery order — the complete 13-lesson set.
final List<Lesson> lessons = List<Lesson>.unmodifiable(<Lesson>[
  lesson01HelloVideo,
  lesson02TextAndMotion,
  lesson03TimingAndTriggers,
  lesson04ScenesAndTransitions,
  lesson05ImagesAndClips,
  lesson06Collage,
  lesson07Charts,
  lesson08CodeDocIntro,
  lesson09DiagramsAndWebviews,
  lesson10AudioAndCaptions,
  lesson11TemplatesAndAspects,
  lesson12TheKitchenSink,
  lesson13GenerativeContent,
]);

/// The lesson registered under [id], or `null` for an unknown id.
Lesson? lessonForId(String id) {
  for (final lesson in lessons) {
    if (lesson.id == id) return lesson;
  }
  return null;
}
