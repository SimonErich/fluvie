Feature: Effects and Transitions

  Scenario: ColorFilter Effect
    Given I apply a VintageEffect to a Clip
    When the FFmpegFilterGraphBuilder processes the RenderConfig
    Then the output filtergraph includes a curves filter applied to the clip's stream label

  Scenario: CrossFade Transition
    Given I define two consecutive Timelines with a CrossFadeTransition lasting 15 frames
    When the FFmpegFilterGraphBuilder processes the transition point
    Then the output filtergraph uses an overlay filter with an enable and alpha expression

  Scenario: TextClip Animation
    Given I use a TextClip and animate its opacity using Interpolate based on the frame number
    When the FrameSequencer captures frames during the animation
    Then the intermediate PNG sequence shows the text element fading smoothly
