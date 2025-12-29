Feature: Spotify Wrapped Templates
  As a developer using fluvie
  I want to use pre-built Spotify Wrapped style templates
  So that I can quickly create engaging video content

  Scenario: Intro template renders with data
    Given I have an IntroData with title "Your 2024"
    When I create a TheNeonGate template with the data
    Then the template should build without errors
    And the template should have category "intro"

  Scenario: Ranking template renders with items
    Given I have a RankingData with 5 items
    When I create a StackClimb template with the data
    Then the template should build without errors
    And the template should have category "ranking"

  Scenario: Data visualization template renders metrics
    Given I have a DataVizData with 3 metrics
    When I create a LiquidMinutes template with the data
    Then the template should build without errors
    And the template should have category "dataViz"

  Scenario: Collage template renders images
    Given I have a CollageData with 9 images
    When I create a TheGridShuffle template with the data
    Then the template should build without errors
    And the template should have category "collage"

  Scenario: Thematic template renders content
    Given I have a ThematicData with text "Your Music Journey"
    When I create a LofiWindow template with the data
    Then the template should build without errors
    And the template should have category "thematic"

  Scenario: Conclusion template renders summary
    Given I have a SummaryData with title "See You Next Year"
    When I create a TheSummaryPoster template with the data
    Then the template should build without errors
    And the template should have category "conclusion"

  Scenario: Templates can be converted to scenes
    Given I have an IntroData with title "Your 2024"
    When I create a TheNeonGate template with the data
    Then the template can be converted to a Scene
    And the scene has a recommended length

  Scenario: Templates support custom themes
    Given I have an IntroData with title "Your 2024"
    When I create a TheNeonGate template with neon theme
    Then the template should use the neon color palette

  Scenario: Audio reactive widgets work with mock provider
    Given I have a MockAudioDataProvider with 120 BPM
    When I initialize the audio provider
    Then I can get the BPM value
    And I can get beat strength at frame 30
