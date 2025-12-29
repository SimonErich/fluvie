Feature: Declarative API Utilities
  As a video creator
  I want to use utility classes for easing and frame ranges
  So that I can simplify animation timing calculations

  Scenario: Easing curves are accessible
    Given I have access to the Easing class
    Then the Easing class should provide standard curves
    And the Easing class should provide cubic curves
    And the Easing class should provide back curves with overshoot
    And the Easing class should provide elastic and bounce curves

  Scenario: FrameRange calculates duration correctly
    Given I create a FrameRange from 30 to 120
    Then the duration should be 90 frames

  Scenario: FrameRange contains checks work correctly
    Given I create a FrameRange from 30 to 120
    Then frame 29 should not be contained
    And frame 30 should be contained
    And frame 75 should be contained
    And frame 119 should be contained
    And frame 120 should not be contained

  Scenario: FrameRange progress calculation
    Given I create a FrameRange from 0 to 100
    Then progress at frame -10 should be 0.0
    And progress at frame 0 should be 0.0
    And progress at frame 25 should be 0.25
    And progress at frame 50 should be 0.5
    And progress at frame 75 should be 0.75
    And progress at frame 100 should be 1.0
    And progress at frame 150 should be 1.0

  Scenario: FrameRange fromDuration factory
    Given I create a FrameRange from duration starting at 60 with duration 90
    Then the start should be 60
    And the end should be 150
    And the duration should be 90 frames

  Scenario: FrameRange fromSeconds factory
    Given I create a FrameRange from seconds at 30fps from 1.0s to 3.0s
    Then the start should be 30
    And the end should be 90
    And the duration should be 60 frames

  Scenario: FrameRange offset operation
    Given I create a FrameRange from 0 to 100
    When I offset the range by 50 frames
    Then the start should be 50
    And the end should be 150

  Scenario: FrameRange overlap detection
    Given I create a FrameRange from 0 to 100
    And I create another FrameRange from 50 to 150
    Then the ranges should overlap
    And the intersection should be from 50 to 100

  Scenario: FrameRange keyframes generation
    Given I create a FrameRange from 0 to 100
    When I generate 5 keyframes
    Then the keyframes should be 0, 25, 50, 75, 100
