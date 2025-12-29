# AudioReactive

> **Create visuals that respond to audio data**

`AudioReactive` provides audio analysis data to descendant widgets, enabling beat-synced animations, frequency visualizations, and other audio-responsive effects.

## Table of Contents

- [Overview](#overview)
- [Widgets](#widgets)
- [AudioDataProvider](#audiodataprovider)
- [Examples](#examples)
- [Built-in Visualizations](#built-in-visualizations)
- [Related](#related)

---

## Overview

`AudioReactive` uses an `InheritedWidget` pattern to make audio analysis data available throughout the widget tree:

```dart
AudioReactive(
  provider: myAudioProvider,
  child: TimeConsumer(
    builder: (context, frame, _) {
      final audioData = AudioReactive.of(context);
      final beatStrength = audioData?.provider.getBeatStrengthAt(frame) ?? 0;

      return Transform.scale(
        scale: 1.0 + beatStrength * 0.2,
        child: Circle(),
      );
    },
  ),
)
```

---

## Widgets

### AudioReactive

The `InheritedWidget` that provides audio data:

```dart
AudioReactive(
  provider: myAudioProvider,
  isReady: true,
  child: Content(),
)
```

| Property | Type | Description |
|----------|------|-------------|
| `provider` | `AudioDataProvider` | Audio analysis provider |
| `isReady` | `bool` | Whether data is ready to use |
| `child` | `Widget` | Child widget tree |

### AudioReactiveBuilder

Handles async initialization of the audio provider:

```dart
AudioReactiveBuilder(
  provider: MockAudioDataProvider(bpm: 120),
  loadingBuilder: (context) => CircularProgressIndicator(),
  errorBuilder: (context, error) => Text('Error: $error'),
  builder: (context, provider) {
    return MyVideoComposition();
  },
)
```

| Property | Type | Description |
|----------|------|-------------|
| `provider` | `AudioDataProvider` | Provider to initialize |
| `builder` | `Widget Function(context, provider)` | Builder when ready |
| `loadingBuilder` | `Widget Function(context)?` | Loading state builder |
| `errorBuilder` | `Widget Function(context, error)?` | Error state builder |

---

## AudioDataProvider

The `AudioDataProvider` abstract class defines the interface for audio analysis:

### Available Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getBpm()` | `double` | Beats per minute |
| `getAmplitudeAt(frame, fps)` | `double` | Volume level (0.0-1.0) |
| `getBeatStrengthAt(frame, fps)` | `double` | Beat intensity (0.0-1.0) |
| `isBeatAt(frame, fps, threshold)` | `bool` | Whether there's a beat |
| `getFrequencyBandsAt(frame, fps, bandCount)` | `List<double>` | Frequency spectrum |
| `getBassAt(frame, fps)` | `double` | Low frequency level |
| `getMidAt(frame, fps)` | `double` | Mid frequency level |
| `getTrebleAt(frame, fps)` | `double` | High frequency level |

### MockAudioDataProvider

For testing and prototyping:

```dart
final provider = MockAudioDataProvider(
  bpm: 120,
  // Optional: custom beat pattern
);
```

---

## Examples

### Beat-Synced Scale

```dart
AudioReactive(
  provider: audioProvider,
  child: TimeConsumer(
    builder: (context, frame, _) {
      final audioData = AudioReactive.of(context);
      final beatStrength = audioData?.provider.getBeatStrengthAt(frame) ?? 0;

      return Transform.scale(
        scale: 1.0 + beatStrength * 0.3,  // Scale up on beat
        child: LogoWidget(),
      );
    },
  ),
)
```

### Bass-Reactive Color

```dart
AudioReactive(
  provider: audioProvider,
  child: TimeConsumer(
    builder: (context, frame, _) {
      final audioData = AudioReactive.of(context);
      final bass = audioData?.provider.getBassAt(frame) ?? 0;

      return Container(
        color: Color.lerp(Colors.blue, Colors.purple, bass),
        child: Content(),
      );
    },
  ),
)
```

### Beat Flash

```dart
AudioReactive(
  provider: audioProvider,
  child: TimeConsumer(
    builder: (context, frame, _) {
      final audioData = AudioReactive.of(context);
      final isBeat = audioData?.provider.isBeatAt(frame, threshold: 0.7) ?? false;

      return Container(
        color: isBeat ? Colors.white : Colors.black,
        child: Content(),
      );
    },
  ),
)
```

### Using AudioReactiveMixin

For cleaner code in custom widgets:

```dart
class PulsingCircle extends StatelessWidget with AudioReactiveMixin {
  final int frame;

  const PulsingCircle({required this.frame});

  @override
  Widget build(BuildContext context) {
    final beatStrength = getBeatStrength(context, frame);
    final bass = getBass(context, frame);

    return Container(
      width: 100 + beatStrength * 50,
      height: 100 + beatStrength * 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.withOpacity(0.5 + bass * 0.5),
      ),
    );
  }
}
```

### Mixin Methods

The `AudioReactiveMixin` provides convenient access methods:

```dart
// Get provider
AudioDataProvider? getAudioProvider(context)

// Get metrics
double getBpm(context)
double getAmplitude(context, frame)
double getBeatStrength(context, frame)
bool isBeat(context, frame, threshold)
List<double> getFrequencyBands(context, frame, bandCount)
double getBass(context, frame)
double getMid(context, frame)
double getTreble(context, frame)
```

---

## Built-in Visualizations

### BeatPulse

Applies a pulsing scale effect:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    return BeatPulse(
      frame: frame,
      minScale: 1.0,
      maxScale: 1.2,
      threshold: 0.3,
      child: Text('Pulse!'),
    );
  },
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Widget to pulse |
| `frame` | `int?` | `null` | Current frame |
| `minScale` | `double` | `1.0` | Scale at no beat |
| `maxScale` | `double` | `1.15` | Scale at full beat |
| `threshold` | `double` | `0.3` | Beat detection threshold |
| `fps` | `int` | `30` | Frames per second |

### FrequencyBars

Visualizes frequency spectrum as bars:

```dart
TimeConsumer(
  builder: (context, frame, _) {
    return FrequencyBars(
      frame: frame,
      barCount: 8,
      barWidth: 20,
      maxHeight: 100,
      spacing: 4,
      color: Colors.green,
      mirror: false,
    );
  },
)
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `frame` | `int` | **required** | Current frame |
| `barCount` | `int` | `8` | Number of bars |
| `barWidth` | `double` | `20` | Width of each bar |
| `maxHeight` | `double` | `100` | Maximum bar height |
| `spacing` | `double` | `4` | Space between bars |
| `color` | `Color` | green | Bar color |
| `gradient` | `Gradient?` | `null` | Optional gradient |
| `mirror` | `bool` | `false` | Show mirrored bars |
| `borderRadius` | `BorderRadius?` | `null` | Bar corners |

---

## Complete Example

```dart
class AudioVisualizer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AudioReactiveBuilder(
      provider: MockAudioDataProvider(bpm: 120),
      loadingBuilder: (context) => const CircularProgressIndicator(),
      builder: (context, provider) {
        return VideoComposition(
          fps: 30,
          durationInFrames: 300,
          width: 1920,
          height: 1080,
          child: LayerStack(
            children: [
              // Beat-reactive background
              TimeConsumer(
                builder: (context, frame, _) {
                  final audioData = AudioReactive.of(context);
                  final bass = audioData?.provider.getBassAt(frame) ?? 0;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(Colors.purple, Colors.pink, bass)!,
                          Color.lerp(Colors.blue, Colors.cyan, bass)!,
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Centered frequency bars
              VCenter(
                child: TimeConsumer(
                  builder: (context, frame, _) {
                    return FrequencyBars(
                      frame: frame,
                      barCount: 12,
                      barWidth: 30,
                      maxHeight: 200,
                      spacing: 8,
                      color: Colors.white,
                      mirror: true,
                    );
                  },
                ),
              ),

              // Pulsing logo
              VPositioned(
                right: 50,
                bottom: 50,
                child: TimeConsumer(
                  builder: (context, frame, _) {
                    return BeatPulse(
                      frame: frame,
                      minScale: 1.0,
                      maxScale: 1.3,
                      child: Icon(Icons.music_note, size: 48, color: Colors.white),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Related

- [TimeConsumer](../core/time-consumer.md) - Frame-based animation
- [AudioTrack](audio-track.md) - Adding audio
- [Embedding Audio](../../embedding/audio.md) - Audio guide
