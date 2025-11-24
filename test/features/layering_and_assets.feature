Feature: Layering and External Assets

  Scenario: VideoClip Integration
    Given I use a VideoClip of length 10 seconds, starting at frame 30, with a trim of 2 seconds
    When the FFmpegFilterGraphBuilder generates the command
    Then the command includes input flags and a trim filter referencing the external file

  Scenario: LayerStack Z-Index
    Given I use a LayerStack containing a red box and a green circle
    When the FrameSequencer captures any frame
    Then the rasterized image shows the green circle visibly overlaying the red box

  Scenario: Collage Template Layout
    Given I use a CollageTemplate.splitScreen with two child clips
    When the FrameSequencer captures the first frame
    Then the resulting frame image shows both child clips correctly positioned side-by-side
