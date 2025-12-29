// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/i_have_a_vstack_with_two_children.dart';
import './step/the_children_should_be_rendered_in_a_stack.dart';
import './step/i_have_a_vstack_with_startframe30_and_endframe120.dart';
import './step/the_current_frame_is0.dart';
import './step/the_vstack_should_not_be_visible.dart';
import './step/the_current_frame_is75.dart';
import './step/the_vstack_should_be_visible.dart';
import './step/the_current_frame_is150.dart';
import './step/i_have_a_vpositioned_with_left100_and_top200.dart';
import './step/the_child_should_be_positioned_at_left100_and_top200.dart';
import './step/i_have_a_vpositionedfill.dart';
import './step/the_positioned_should_have_all_edges_set_to0.dart';
import './step/i_have_a_vrow_with_three_children.dart';
import './step/the_children_should_be_arranged_in_a_row.dart';
import './step/i_have_a_vrow_with_spacing20.dart';
import './step/there_should_be_sizedbox_spacers_between_children.dart';
import './step/i_have_a_vcolumn_with_three_children.dart';
import './step/the_children_should_be_arranged_in_a_column.dart';
import './step/i_have_a_vcolumn_with_stagger_delay15.dart';
import './step/the_first_child_should_start_animating.dart';
import './step/the_current_frame_is15.dart';
import './step/the_second_child_should_start_animating.dart';
import './step/i_have_a_vcenter_with_a_child.dart';
import './step/the_child_should_be_centered.dart';
import './step/i_have_a_vpadding_with_padding20.dart';
import './step/the_child_should_have20_pixels_of_padding_on_all_sides.dart';
import './step/i_have_a_vpaddingsymmetric_with_horizontal10_and_vertical20.dart';
import './step/the_child_should_have_horizontal_padding_of10.dart';
import './step/the_child_should_have_vertical_padding_of20.dart';
import './step/i_have_a_vsizedbox_with_width200_and_height100.dart';
import './step/the_child_should_be_constrained_to200x100.dart';
import './step/i_have_a_vsizedboxsquare_with_dimension150.dart';
import './step/the_child_should_be_constrained_to150x150.dart';
import './step/i_have_a_vcenter_with_fadeinframes15.dart';
import './step/the_current_frame_is_at_startframe.dart';
import './step/the_opacity_should_be0.dart';
import './step/the_current_frame_is_at_startframe_plus_fadeinframes.dart';
import './step/the_opacity_should_be1.dart';
import './step/i_have_a_vcenter_with_fadeoutframes15.dart';
import './step/the_current_frame_is_at_endframe_minus_fadeoutframes.dart';
import './step/the_current_frame_is_at_endframe.dart';

void main() {
  group('''Declarative Layout Widgets''', () {
    testWidgets('''VStack renders children in a stack''', (tester) async {
      await iHaveAVstackWithTwoChildren(tester);
      await theChildrenShouldBeRenderedInAStack(tester);
    });
    testWidgets('''VStack with timing shows and hides content''', (
      tester,
    ) async {
      await iHaveAVstackWithStartframe30AndEndframe120(tester);
      await theCurrentFrameIs0(tester);
      await theVstackShouldNotBeVisible(tester);
      await theCurrentFrameIs75(tester);
      await theVstackShouldBeVisible(tester);
      await theCurrentFrameIs150(tester);
      await theVstackShouldNotBeVisible(tester);
    });
    testWidgets('''VPositioned positions a child absolutely''', (tester) async {
      await iHaveAVpositionedWithLeft100AndTop200(tester);
      await theChildShouldBePositionedAtLeft100AndTop200(tester);
    });
    testWidgets('''VPositioned.fill creates a filling positioned widget''', (
      tester,
    ) async {
      await iHaveAVpositionedfill(tester);
      await thePositionedShouldHaveAllEdgesSetTo0(tester);
    });
    testWidgets('''VRow renders children horizontally''', (tester) async {
      await iHaveAVrowWithThreeChildren(tester);
      await theChildrenShouldBeArrangedInARow(tester);
    });
    testWidgets('''VRow with spacing adds gaps between children''', (
      tester,
    ) async {
      await iHaveAVrowWithSpacing20(tester);
      await thereShouldBeSizedboxSpacersBetweenChildren(tester);
    });
    testWidgets('''VColumn renders children vertically''', (tester) async {
      await iHaveAVcolumnWithThreeChildren(tester);
      await theChildrenShouldBeArrangedInAColumn(tester);
    });
    testWidgets('''VColumn with stagger animates children sequentially''', (
      tester,
    ) async {
      await iHaveAVcolumnWithStaggerDelay15(tester);
      await theCurrentFrameIs0(tester);
      await theFirstChildShouldStartAnimating(tester);
      await theCurrentFrameIs15(tester);
      await theSecondChildShouldStartAnimating(tester);
    });
    testWidgets('''VCenter centers its child''', (tester) async {
      await iHaveAVcenterWithAChild(tester);
      await theChildShouldBeCentered(tester);
    });
    testWidgets('''VPadding adds padding around child''', (tester) async {
      await iHaveAVpaddingWithPadding20(tester);
      await theChildShouldHave20PixelsOfPaddingOnAllSides(tester);
    });
    testWidgets('''VPadding.symmetric creates symmetric padding''', (
      tester,
    ) async {
      await iHaveAVpaddingsymmetricWithHorizontal10AndVertical20(tester);
      await theChildShouldHaveHorizontalPaddingOf10(tester);
      await theChildShouldHaveVerticalPaddingOf20(tester);
    });
    testWidgets('''VSizedBox constrains child size''', (tester) async {
      await iHaveAVsizedboxWithWidth200AndHeight100(tester);
      await theChildShouldBeConstrainedTo200x100(tester);
    });
    testWidgets('''VSizedBox.square creates a square box''', (tester) async {
      await iHaveAVsizedboxsquareWithDimension150(tester);
      await theChildShouldBeConstrainedTo150x150(tester);
    });
    testWidgets('''Layout widgets support fade in''', (tester) async {
      await iHaveAVcenterWithFadeinframes15(tester);
      await theCurrentFrameIsAtStartframe(tester);
      await theOpacityShouldBe0(tester);
      await theCurrentFrameIsAtStartframePlusFadeinframes(tester);
      await theOpacityShouldBe1(tester);
    });
    testWidgets('''Layout widgets support fade out''', (tester) async {
      await iHaveAVcenterWithFadeoutframes15(tester);
      await theCurrentFrameIsAtEndframeMinusFadeoutframes(tester);
      await theOpacityShouldBe1(tester);
      await theCurrentFrameIsAtEndframe(tester);
      await theOpacityShouldBe0(tester);
    });
  });
}
