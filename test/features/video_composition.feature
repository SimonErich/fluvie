Feature: Video Composition and Time Synchronization

  Scenario: Simple Composition Length
    Given I define a VideoComposition with fps: 30 and durationInFrames: 90
    When the RenderService executes the composition
    Then the final video file duration is exactly 3.0 seconds

  Scenario: Driver Interpolation Accuracy
    Given I use a TimeConsumer to animate a circle's x position from 0 to 100 between frame 0 and frame 100
    When the FrameSequencer captures frame 50
    Then the rasterized image for frame 50 contains the circle centered at x: 50

  Scenario: Repaint Boundary Integrity
    Given I define a VideoComposition wrapped in a RepaintBoundary
    When I inspect the RenderConfig output
    Then the GlobalKey for the boundary is correctly registered for the FrameSequencer
