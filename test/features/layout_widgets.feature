Feature: Declarative Layout Widgets
  As a video creator
  I want to use video-aware layout widgets
  So that I can position content with timing and transitions

  Scenario: VStack renders children in a stack
    Given I have a VStack with two children
    Then the children should be rendered in a Stack

  Scenario: VStack with timing shows and hides content
    Given I have a VStack with startFrame 30 and endFrame 120
    When the current frame is 0
    Then the VStack should not be visible
    When the current frame is 75
    Then the VStack should be visible
    When the current frame is 150
    Then the VStack should not be visible

  Scenario: VPositioned positions a child absolutely
    Given I have a VPositioned with left 100 and top 200
    Then the child should be positioned at left 100 and top 200

  Scenario: VPositioned.fill creates a filling positioned widget
    Given I have a VPositioned.fill
    Then the positioned should have all edges set to 0

  Scenario: VRow renders children horizontally
    Given I have a VRow with three children
    Then the children should be arranged in a Row

  Scenario: VRow with spacing adds gaps between children
    Given I have a VRow with spacing 20
    Then there should be SizedBox spacers between children

  Scenario: VColumn renders children vertically
    Given I have a VColumn with three children
    Then the children should be arranged in a Column

  Scenario: VColumn with stagger animates children sequentially
    Given I have a VColumn with stagger delay 15
    When the current frame is 0
    Then the first child should start animating
    When the current frame is 15
    Then the second child should start animating

  Scenario: VCenter centers its child
    Given I have a VCenter with a child
    Then the child should be centered

  Scenario: VPadding adds padding around child
    Given I have a VPadding with padding 20
    Then the child should have 20 pixels of padding on all sides

  Scenario: VPadding.symmetric creates symmetric padding
    Given I have a VPadding.symmetric with horizontal 10 and vertical 20
    Then the child should have horizontal padding of 10
    And the child should have vertical padding of 20

  Scenario: VSizedBox constrains child size
    Given I have a VSizedBox with width 200 and height 100
    Then the child should be constrained to 200x100

  Scenario: VSizedBox.square creates a square box
    Given I have a VSizedBox.square with dimension 150
    Then the child should be constrained to 150x150

  Scenario: Layout widgets support fade in
    Given I have a VCenter with fadeInFrames 15
    When the current frame is at startFrame
    Then the opacity should be 0
    When the current frame is at startFrame plus fadeInFrames
    Then the opacity should be 1

  Scenario: Layout widgets support fade out
    Given I have a VCenter with fadeOutFrames 15
    When the current frame is at endFrame minus fadeOutFrames
    Then the opacity should be 1
    When the current frame is at endFrame
    Then the opacity should be 0
