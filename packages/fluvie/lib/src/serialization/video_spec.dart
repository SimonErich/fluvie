import 'dart:convert';

import 'package:flutter/widgets.dart' show Widget;
import 'package:fluvie/src/audio/audio.dart' show Audio;
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/defaults.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/export.dart';
import 'package:fluvie/src/core/hash/fnv1a.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/transition.dart';
import 'package:fluvie/src/core/video_size.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/audio_track_spec.dart';
import 'package:fluvie/src/serialization/clip_lane_mix.dart';
import 'package:fluvie/src/serialization/codecs/defaults_codec.dart';
import 'package:fluvie/src/serialization/codecs/export_codec.dart';
import 'package:fluvie/src/serialization/codecs/time_codec.dart';
import 'package:fluvie/src/serialization/codecs/transition_codec.dart';
import 'package:fluvie/src/serialization/codecs/video_size_codec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/element_transition_builder.dart';
import 'package:fluvie/src/serialization/lane_spec.dart';
import 'package:fluvie/src/serialization/master_spec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';
import 'package:fluvie/src/serialization/theme_spec.dart';
import 'package:fluvie/src/timing/placement/scene_frame_resolver.dart';

part 'video_spec_parser.dart';
part 'video_spec_document.dart';
part 'video_spec_encoding.dart';
part 'video_spec_builders.dart';

/// Builds a real [Video] from [spec] — a free-function alias for
/// [VideoSpec.build] that reads naturally at call sites.
Video buildVideo(VideoSpec spec) => spec.build();
