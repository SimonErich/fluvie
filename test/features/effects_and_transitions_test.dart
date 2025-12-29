// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/i_apply_a_vintageeffect_to_a_clip.dart';
import './step/the_ffmpegfiltergraphbuilder_processes_the_renderconfig.dart';
import './step/the_output_filtergraph_includes_a_curves_filter_applied_to_the_clips_stream_label.dart';
import './step/i_define_two_consecutive_timelines_with_a_crossfadetransition_lasting15_frames.dart';
import './step/the_ffmpegfiltergraphbuilder_processes_the_transition_point.dart';
import './step/the_output_filtergraph_uses_an_overlay_filter_with_an_enable_and_alpha_expression.dart';
import './step/i_use_a_textclip_and_animate_its_opacity_using_interpolate_based_on_the_frame_number.dart';
import './step/the_framesequencer_captures_frames_during_the_animation.dart';
import './step/the_intermediate_png_sequence_shows_the_text_element_fading_smoothly.dart';

void main() {
  group('''Effects and Transitions''', () {
    testWidgets('''ColorFilter Effect''', (tester) async {
      await iApplyAVintageeffectToAClip(tester);
      await theFfmpegfiltergraphbuilderProcessesTheRenderconfig(tester);
      await theOutputFiltergraphIncludesACurvesFilterAppliedToTheClipsStreamLabel(
        tester,
      );
    });
    testWidgets('''CrossFade Transition''', (tester) async {
      await iDefineTwoConsecutiveTimelinesWithACrossfadetransitionLasting15Frames(
        tester,
      );
      await theFfmpegfiltergraphbuilderProcessesTheTransitionPoint(tester);
      await theOutputFiltergraphUsesAnOverlayFilterWithAnEnableAndAlphaExpression(
        tester,
      );
    });
    testWidgets('''TextSequence Animation''', (tester) async {
      await iUseATextclipAndAnimateItsOpacityUsingInterpolateBasedOnTheFrameNumber(
        tester,
      );
      await theFramesequencerCapturesFramesDuringTheAnimation(tester);
      await theIntermediatePngSequenceShowsTheTextElementFadingSmoothly(tester);
    });
  });
}
