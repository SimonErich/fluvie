# Fluvie Widgets

## Core Widgets

### VideoComposition
The root widget for any Fluvie project. It defines the global properties like FPS and duration.

### Clip
A container for video segments. Use `startFrame` and `durationInFrames` to schedule when content appears.

### TimeConsumer
Provides access to the current frame number and progress (0.0 to 1.0). Use this to drive animations.

## Layout & Composition

### LayerStack
A stack-like widget for layering content.

### CollageTemplate
Pre-defined layouts like `CollageTemplate.splitScreen`.

## Assets

### VideoClip
Embeds an external video file. Supports trimming.

### TextClip
Renders text with style.

## Transitions

### CrossFadeTransition
Smoothly fades between two widgets over a specified duration.
