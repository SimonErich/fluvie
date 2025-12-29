// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/i_have_access_to_the_easing_class.dart';
import './step/the_easing_class_should_provide_standard_curves.dart';
import './step/the_easing_class_should_provide_cubic_curves.dart';
import './step/the_easing_class_should_provide_back_curves_with_overshoot.dart';
import './step/the_easing_class_should_provide_elastic_and_bounce_curves.dart';
import './step/i_create_a_framerange_from30_to120.dart';
import './step/the_duration_should_be90_frames.dart';
import './step/frame29_should_not_be_contained.dart';
import './step/frame30_should_be_contained.dart';
import './step/frame75_should_be_contained.dart';
import './step/frame119_should_be_contained.dart';
import './step/frame120_should_not_be_contained.dart';
import './step/i_create_a_framerange_from0_to100.dart';
import './step/progress_at_frame10_should_be00.dart';
import './step/progress_at_frame0_should_be00.dart';
import './step/progress_at_frame25_should_be025.dart';
import './step/progress_at_frame50_should_be05.dart';
import './step/progress_at_frame75_should_be075.dart';
import './step/progress_at_frame100_should_be10.dart';
import './step/progress_at_frame150_should_be10.dart';
import './step/i_create_a_framerange_from_duration_starting_at60_with_duration90.dart';
import './step/the_start_should_be60.dart';
import './step/the_end_should_be150.dart';
import './step/i_create_a_framerange_from_seconds_at30fps_from10s_to30s.dart';
import './step/the_start_should_be30.dart';
import './step/the_end_should_be90.dart';
import './step/the_duration_should_be60_frames.dart';
import './step/i_offset_the_range_by50_frames.dart';
import './step/the_start_should_be50.dart';
import './step/i_create_another_framerange_from50_to150.dart';
import './step/the_ranges_should_overlap.dart';
import './step/the_intersection_should_be_from50_to100.dart';
import './step/i_generate5_keyframes.dart';
import './step/the_keyframes_should_be0255075100.dart';

void main() {
  group('''Declarative API Utilities''', () {
    testWidgets('''Easing curves are accessible''', (tester) async {
      await iHaveAccessToTheEasingClass(tester);
      await theEasingClassShouldProvideStandardCurves(tester);
      await theEasingClassShouldProvideCubicCurves(tester);
      await theEasingClassShouldProvideBackCurvesWithOvershoot(tester);
      await theEasingClassShouldProvideElasticAndBounceCurves(tester);
    });
    testWidgets('''FrameRange calculates duration correctly''', (tester) async {
      await iCreateAFramerangeFrom30To120(tester);
      await theDurationShouldBe90Frames(tester);
    });
    testWidgets('''FrameRange contains checks work correctly''',
        (tester) async {
      await iCreateAFramerangeFrom30To120(tester);
      await frame29ShouldNotBeContained(tester);
      await frame30ShouldBeContained(tester);
      await frame75ShouldBeContained(tester);
      await frame119ShouldBeContained(tester);
      await frame120ShouldNotBeContained(tester);
    });
    testWidgets('''FrameRange progress calculation''', (tester) async {
      await iCreateAFramerangeFrom0To100(tester);
      await progressAtFrame10ShouldBe00(tester);
      await progressAtFrame0ShouldBe00(tester);
      await progressAtFrame25ShouldBe025(tester);
      await progressAtFrame50ShouldBe05(tester);
      await progressAtFrame75ShouldBe075(tester);
      await progressAtFrame100ShouldBe10(tester);
      await progressAtFrame150ShouldBe10(tester);
    });
    testWidgets('''FrameRange fromDuration factory''', (tester) async {
      await iCreateAFramerangeFromDurationStartingAt60WithDuration90(tester);
      await theStartShouldBe60(tester);
      await theEndShouldBe150(tester);
      await theDurationShouldBe90Frames(tester);
    });
    testWidgets('''FrameRange fromSeconds factory''', (tester) async {
      await iCreateAFramerangeFromSecondsAt30fpsFrom10sTo30s(tester);
      await theStartShouldBe30(tester);
      await theEndShouldBe90(tester);
      await theDurationShouldBe60Frames(tester);
    });
    testWidgets('''FrameRange offset operation''', (tester) async {
      await iCreateAFramerangeFrom0To100(tester);
      await iOffsetTheRangeBy50Frames(tester);
      await theStartShouldBe50(tester);
      await theEndShouldBe150(tester);
    });
    testWidgets('''FrameRange overlap detection''', (tester) async {
      await iCreateAFramerangeFrom0To100(tester);
      await iCreateAnotherFramerangeFrom50To150(tester);
      await theRangesShouldOverlap(tester);
      await theIntersectionShouldBeFrom50To100(tester);
    });
    testWidgets('''FrameRange keyframes generation''', (tester) async {
      await iCreateAFramerangeFrom0To100(tester);
      await iGenerate5Keyframes(tester);
      await theKeyframesShouldBe0255075100(tester);
    });
  });
}
