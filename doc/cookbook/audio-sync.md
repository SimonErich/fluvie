# Sync Animations to Music Beats

Create beat-synchronized animations that move in time with your music.

## Problem

You want animations to pulse, scale, or move in perfect sync with the beats in your background music.

## Solution

Use `SyncAnchor` with BPM detection to create beat-aligned animations.

### Basic Beat Sync

```dart
import 'package:flutter/material.dart';
import 'package:fluvie/fluvie.dart';

final composition = VideoComposition(
  fps: 30,
  durationInFrames: 300,  // 10 seconds
  width: 1920,
  height: 1080,
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/music.mp3'),
      bpm: 120,  // Beats per minute
      startFrame: 0,
      durationInFrames: 300,
    ),
  ],
  child: LayerStack(
    children: [
      // Background
      Layer.background(
        child: Container(color: Colors.black),
      ),

      // Beat-synchronized circle
      Layer(
        id: 'pulse_circle',
        startFrame: 0,
        endFrame: 300,
        child: SyncAnchor(
          id: 'beat_1',
          frame: 0,  // First beat at frame 0
          child: TimeConsumer(
            builder: (context, frame, progress) {
              // Get progress since last beat
              final beatProgress = context.getProgressSince('beat_1');

              // Scale based on beat (pulse effect)
              final scale = 1.0 + (0.3 * (1 - beatProgress));

              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  ),
);
```

### Multiple Beat Anchors

For complex patterns, use multiple sync anchors:

```dart
child: Stack(
  children: [
    // Place sync anchors at beat intervals
    // At 120 BPM and 30 FPS: 15 frames per beat
    SyncAnchor(id: 'beat_0', frame: 0),
    SyncAnchor(id: 'beat_1', frame: 15),
    SyncAnchor(id: 'beat_2', frame: 30),
    SyncAnchor(id: 'beat_3', frame: 45),
    SyncAnchor(id: 'beat_4', frame: 60),
    // ... continue for all beats

    TimeConsumer(
      builder: (context, frame, progress) {
        // Find closest beat anchor
        final currentBeat = (frame / 15).floor();
        final beatProgress = (frame % 15) / 15.0;

        // Animate based on beat progress
        return AnimatedElement(beatProgress: beatProgress);
      },
    ),
  ],
)
```

### Auto-Generate Beat Anchors

Helper function to generate anchors from BPM:

```dart
List<Widget> generateBeatAnchors({
  required int bpm,
  required int fps,
  required int durationInFrames,
}) {
  final framesPerBeat = (fps * 60 / bpm).round();
  final anchors = <Widget>[];

  for (int i = 0; i * framesPerBeat < durationInFrames; i++) {
    anchors.add(
      SyncAnchor(
        id: 'beat_$i',
        frame: i * framesPerBeat,
      ),
    );
  }

  return anchors;
}

// Usage:
child: Stack(
  children: [
    ...generateBeatAnchors(bpm: 120, fps: 30, durationInFrames: 300),
    TimeConsumer(builder: ...),
  ],
)
```

## Expected Output

- Elements pulse in perfect sync with music beats
- Animation timing matches BPM precisely
- Smooth transitions between beats

## Variations

### Color Flash on Beat

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final beatProgress = (frame % framesPerBeat) / framesPerBeat;

    // Flash white at beat, fade to color
    final color = Color.lerp(
      Colors.white,
      Colors.blue,
      beatProgress,
    )!;

    return Container(color: color);
  },
)
```

### Shake Effect on Beat

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final beatProgress = (frame % framesPerBeat) / framesPerBeat;

    // Shake decreases after beat
    final shakeAmount = 10 * (1 - beatProgress);
    final offsetX = math.sin(frame * 0.5) * shakeAmount;

    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: YourWidget(),
    );
  },
)
```

### Sequential Element Reveals

Reveal elements one per beat:

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final currentBeat = (frame / framesPerBeat).floor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final isVisible = index <= currentBeat;

        return AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: Duration.zero,
          child: Container(
            width: 100,
            height: 100,
            margin: EdgeInsets.all(8),
            color: Colors.blue,
          ),
        );
      }),
    );
  },
)
```

## Advanced: Beat Detection

For audio files without known BPM, use audio analysis:

```dart
import 'package:fluvie/fluvie.dart';

// Analyze audio file for beats
final audioAnalysis = await AudioAnalyzer.analyze(
  path: 'assets/music.mp3',
);

final bpm = audioAnalysis.bpm;
final beatFrames = audioAnalysis.beatFrames;

// Use detected beats
final anchors = beatFrames.map((frame) =>
  SyncAnchor(id: 'beat_${beatFrames.indexOf(frame)}', frame: frame)
).toList();
```

## Tips

1. **Calculate frames per beat**: `framesPerBeat = (fps * 60) / bpm`
   - 120 BPM at 30 FPS = 15 frames per beat
   - 140 BPM at 30 FPS = 12.86 frames per beat (round to 13)

2. **Use easing curves**: `Curves.easeOut` works well for beat pulses

3. **Layer multiple effects**: Combine scale, color, and position changes

4. **Test with headphones**: Ensure sync is perfect

5. **Account for audio offset**: If audio starts late, offset beat anchors

## Common Pitfalls

❌ **Integer rounding errors**:
```dart
// Wrong: Loses precision over time
final framesPerBeat = (fps * 60 / bpm).toInt();
```

✅ **Maintain precision**:
```dart
// Right: Use round() and adjust as needed
final framesPerBeat = (fps * 60 / bpm).round();
```

❌ **Forgetting audio delay**:
If audio starts at frame 30, offset all beat anchors by 30 frames.

## Related

- [Background Music with Fade](background-music.md) - Add music to videos
- [Multiple Audio Tracks](multi-track-audio.md) - Layer audio sources
- [Animated Title Sequences](animated-titles.md) - Time titles to beats

## Full API Reference

- [`SyncAnchor`](../widgets/audio-widgets.md#syncanchor)
- [`AudioTrack`](../widgets/audio-widgets.md#audiotrack)
- [`TimeConsumer`](../widgets/core-widgets.md#timeconsumer)
