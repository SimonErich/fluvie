// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/i_have_an_introdata_with_title_your2024.dart';
import './step/i_create_a_theneongate_template_with_the_data.dart';
import './step/the_template_should_build_without_errors.dart';
import './step/the_template_should_have_category_intro.dart';
import './step/i_have_a_rankingdata_with5_items.dart';
import './step/i_create_a_stackclimb_template_with_the_data.dart';
import './step/the_template_should_have_category_ranking.dart';
import './step/i_have_a_datavizdata_with3_metrics.dart';
import './step/i_create_a_liquidminutes_template_with_the_data.dart';
import './step/the_template_should_have_category_dataviz.dart';
import './step/i_have_a_collagedata_with9_images.dart';
import './step/i_create_a_thegridshuffle_template_with_the_data.dart';
import './step/the_template_should_have_category_collage.dart';
import './step/i_have_a_thematicdata_with_text_your_music_journey.dart';
import './step/i_create_a_lofiwindow_template_with_the_data.dart';
import './step/the_template_should_have_category_thematic.dart';
import './step/i_have_a_summarydata_with_title_see_you_next_year.dart';
import './step/i_create_a_thesummaryposter_template_with_the_data.dart';
import './step/the_template_should_have_category_conclusion.dart';
import './step/the_template_can_be_converted_to_a_scene.dart';
import './step/the_scene_has_a_recommended_length.dart';
import './step/i_create_a_theneongate_template_with_neon_theme.dart';
import './step/the_template_should_use_the_neon_color_palette.dart';
import './step/i_have_a_mockaudiodataprovider_with120_bpm.dart';
import './step/i_initialize_the_audio_provider.dart';
import './step/i_can_get_the_bpm_value.dart';
import './step/i_can_get_beat_strength_at_frame30.dart';

void main() {
  group('''Spotify Wrapped Templates''', () {
    testWidgets('''Intro template renders with data''', (tester) async {
      await iHaveAnIntrodataWithTitleYour2024(tester);
      await iCreateATheneongateTemplateWithTheData(tester);
      await theTemplateShouldBuildWithoutErrors(tester);
      await theTemplateShouldHaveCategoryIntro(tester);
    });
    testWidgets('''Ranking template renders with items''', (tester) async {
      await iHaveARankingdataWith5Items(tester);
      await iCreateAStackclimbTemplateWithTheData(tester);
      await theTemplateShouldBuildWithoutErrors(tester);
      await theTemplateShouldHaveCategoryRanking(tester);
    });
    testWidgets('''Data visualization template renders metrics''', (
      tester,
    ) async {
      await iHaveADatavizdataWith3Metrics(tester);
      await iCreateALiquidminutesTemplateWithTheData(tester);
      await theTemplateShouldBuildWithoutErrors(tester);
      await theTemplateShouldHaveCategoryDataviz(tester);
    });
    testWidgets('''Collage template renders images''', (tester) async {
      await iHaveACollagedataWith9Images(tester);
      await iCreateAThegridshuffleTemplateWithTheData(tester);
      await theTemplateShouldBuildWithoutErrors(tester);
      await theTemplateShouldHaveCategoryCollage(tester);
    });
    testWidgets('''Thematic template renders content''', (tester) async {
      await iHaveAThematicdataWithTextYourMusicJourney(tester);
      await iCreateALofiwindowTemplateWithTheData(tester);
      await theTemplateShouldBuildWithoutErrors(tester);
      await theTemplateShouldHaveCategoryThematic(tester);
    });
    testWidgets('''Conclusion template renders summary''', (tester) async {
      await iHaveASummarydataWithTitleSeeYouNextYear(tester);
      await iCreateAThesummaryposterTemplateWithTheData(tester);
      await theTemplateShouldBuildWithoutErrors(tester);
      await theTemplateShouldHaveCategoryConclusion(tester);
    });
    testWidgets('''Templates can be converted to scenes''', (tester) async {
      await iHaveAnIntrodataWithTitleYour2024(tester);
      await iCreateATheneongateTemplateWithTheData(tester);
      await theTemplateCanBeConvertedToAScene(tester);
      await theSceneHasARecommendedLength(tester);
    });
    testWidgets('''Templates support custom themes''', (tester) async {
      await iHaveAnIntrodataWithTitleYour2024(tester);
      await iCreateATheneongateTemplateWithNeonTheme(tester);
      await theTemplateShouldUseTheNeonColorPalette(tester);
    });
    testWidgets('''Audio reactive widgets work with mock provider''', (
      tester,
    ) async {
      await iHaveAMockaudiodataproviderWith120Bpm(tester);
      await iInitializeTheAudioProvider(tester);
      await iCanGetTheBpmValue(tester);
      await iCanGetBeatStrengthAtFrame30(tester);
    });
  });
}
