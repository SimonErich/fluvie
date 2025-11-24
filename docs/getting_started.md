# Getting Started with Fluvie

Fluvie allows you to generate videos programmatically using Flutter widgets.

## Installation

Add `fluvie` to your `pubspec.yaml`:

```yaml
dependencies:
  fluvie: ^0.0.1
```

## Basic Usage

1.  **Define your composition:**

    Wrap your content in a `VideoComposition` widget. This sets the frame rate and duration.

    ```dart
    final composition = VideoComposition(
      fps: 30,
      durationInFrames: 150, // 5 seconds
      child: MyVideoContent(),
    );
    ```

2.  **Create content with Clips:**

    Use `Clip` widgets to sequence your content.

    ```dart
    class MyVideoContent extends StatelessWidget {
      @override
      Widget build(BuildContext context) {
        return Stack(
          children: [
            Clip(
              startFrame: 0,
              durationInFrames: 60,
              child: Text('Scene 1'),
            ),
            Clip(
              startFrame: 60,
              durationInFrames: 90,
              child: Text('Scene 2'),
            ),
          ],
        );
      }
    }
    ```

3.  **Animate using TimeConsumer:**

    Use `TimeConsumer` to access the current frame and animate properties.

    ```dart
    TimeConsumer(
      builder: (context, frame, progress) {
        return Opacity(
          opacity: progress,
          child: Text('Fading In'),
        );
      },
    )
    ```

4.  **Render the video:**

    Use `RenderService` to export the video.

    ```dart
    final service = RenderService();
    // In a real app, you would trigger this from a button or command
    // service.execute(config: ...);
    ```

## Architecture

Fluvie uses a "Dual-Engine" architecture:
- **Flutter** renders each frame as an image.
- **FFmpeg** combines these images into a video file.

See `docs/concept.md` for more details.
