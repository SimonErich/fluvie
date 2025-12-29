// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/i_use_a_videoclip_of_length10_seconds_starting_at_frame30_with_a_trim_of2_seconds.dart';
import './step/the_ffmpegfiltergraphbuilder_generates_the_command.dart';
import './step/the_command_includes_input_flags_and_a_trim_filter_referencing_the_external_file.dart';
import './step/i_use_a_layerstack_containing_a_red_box_and_a_green_circle.dart';
import './step/the_framesequencer_captures_any_frame.dart';
import './step/the_rasterized_image_shows_the_green_circle_visibly_overlaying_the_red_box.dart';
import './step/i_use_a_collagetemplatesplitscreen_with_two_child_clips.dart';
import './step/the_framesequencer_captures_the_first_frame.dart';
import './step/the_resulting_frame_image_shows_both_child_clips_correctly_positioned_sidebyside.dart';

void main() {
  group('''Layering and External Assets''', () {
    testWidgets('''VideoSequence Integration''', (tester) async {
      await iUseAVideoclipOfLength10SecondsStartingAtFrame30WithATrimOf2Seconds(
        tester,
      );
      await theFfmpegfiltergraphbuilderGeneratesTheCommand(tester);
      await theCommandIncludesInputFlagsAndATrimFilterReferencingTheExternalFile(
        tester,
      );
    });
    testWidgets('''LayerStack Z-Index''', (tester) async {
      await iUseALayerstackContainingARedBoxAndAGreenCircle(tester);
      await theFramesequencerCapturesAnyFrame(tester);
      await theRasterizedImageShowsTheGreenCircleVisiblyOverlayingTheRedBox(
        tester,
      );
    });
    testWidgets('''Collage Template Layout''', (tester) async {
      await iUseACollagetemplatesplitscreenWithTwoChildClips(tester);
      await theFramesequencerCapturesTheFirstFrame(tester);
      await theResultingFrameImageShowsBothChildClipsCorrectlyPositionedSidebyside(
        tester,
      );
    });
  });
}
