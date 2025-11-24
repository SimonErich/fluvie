// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/i_define_a_videocomposition_with_fps30_and_durationinframes90.dart';
import './step/the_renderservice_executes_the_composition.dart';
import './step/the_final_video_file_duration_is_exactly30_seconds.dart';
import './step/i_use_a_timeconsumer_to_animate_a_circles_x_position_from0_to100_between_frame0_and_frame100.dart';
import './step/the_framesequencer_captures_frame50.dart';
import './step/the_rasterized_image_for_frame50_contains_the_circle_centered_at_x50.dart';
import './step/i_define_a_videocomposition_wrapped_in_a_repaintboundary.dart';
import './step/i_inspect_the_renderconfig_output.dart';
import './step/the_globalkey_for_the_boundary_is_correctly_registered_for_the_framesequencer.dart';

void main() {
  group('''Video Composition and Time Synchronization''', () {
    testWidgets('''Simple Composition Length''', (tester) async {
      await iDefineAVideocompositionWithFps30AndDurationinframes90(tester);
      await theRenderserviceExecutesTheComposition(tester);
      await theFinalVideoFileDurationIsExactly30Seconds(tester);
    });
    testWidgets('''Driver Interpolation Accuracy''', (tester) async {
      await iUseATimeconsumerToAnimateACirclesXPositionFrom0To100BetweenFrame0AndFrame100(
          tester);
      await theFramesequencerCapturesFrame50(tester);
      await theRasterizedImageForFrame50ContainsTheCircleCenteredAtX50(tester);
    });
    testWidgets('''Repaint Boundary Integrity''', (tester) async {
      await iDefineAVideocompositionWrappedInARepaintboundary(tester);
      await iInspectTheRenderconfigOutput(tester);
      await theGlobalkeyForTheBoundaryIsCorrectlyRegisteredForTheFramesequencer(
          tester);
    });
  });
}
