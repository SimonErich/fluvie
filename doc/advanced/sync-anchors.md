# Sync Anchors

> **Precise audio-visual synchronization**

Sync anchors allow you to create precise timing relationships between audio and visual elements, perfect for music-reactive content.

## Table of Contents

- [Overview](#overview)
- [SyncAnchor Widget](#syncanchor-widget)
- [SyncAnchorRegistry](#syncanchorregistry)
- [Audio Sync Configurations](#audio-sync-configurations)
- [Examples](#examples)
- [Best Practices](#best-practices)

---

## Overview

Sync anchors create named timing points in your composition that can be referenced by audio tracks for precise synchronization.

### How It Works

1. Place `SyncAnchor` widgets at key visual moments
2. Register sync points with `SyncAnchorRegistry`
3. Reference anchors in audio track configurations
4. Fluvie ensures audio plays at exactly the right frame

---

## SyncAnchor Widget

Mark visual timing points:

```dart
Scene(
  durationInFrames: 180,
  children: [
    // Text appears at frame 60
    SyncAnchor(
      id: 'title_reveal',
      frame: 60,
      child: AnimatedProp(
        startFrame: 60,
        animation: PropAnimation.zoomIn(),
        child: Text('Welcome'),
      ),
    ),
  ],
)
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier for this anchor |
| `frame` | `int` | Frame number this anchor represents |
| `child` | `Widget` | Child widget |

---

## SyncAnchorRegistry

Register and manage sync points:

```dart
final registry = SyncAnchorRegistry();

// Register anchors
registry.register('intro_start', 0);
registry.register('beat_drop', 90);
registry.register('climax', 180);
registry.register('outro', 270);

// Query anchors
final beatDropFrame = registry.getFrame('beat_drop');  // 90
```

### Automatic Registration

Anchors are automatically registered when `SyncAnchor` widgets build:

```dart
Scene(
  children: [
    SyncAnchor(id: 'section_a', frame: 0, child: ...),
    SyncAnchor(id: 'section_b', frame: 90, child: ...),
  ],
)

// Registry automatically contains 'section_a' and 'section_b'
```

---

## Audio Sync Configurations

### Sync Audio to Anchor

```dart
Video(
  scenes: [
    Scene(
      durationInFrames: 180,
      children: [
        SyncAnchor(
          id: 'impact',
          frame: 60,
          child: AnimatedProp(
            startFrame: 60,
            animation: PropAnimation.zoomIn(),
            child: Image.asset('assets/explosion.png'),
          ),
        ),
      ],
    ),
  ],
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/boom.mp3'),
      syncToAnchor: 'impact',  // Plays at frame 60
    ),
  ],
)
```

### Multiple Synced Sounds

```dart
audioTracks: [
  // Background music (no sync)
  AudioTrack(
    source: AudioSource.asset('assets/music.mp3'),
    volume: 0.6,
  ),

  // Whoosh at title reveal
  AudioTrack(
    source: AudioSource.asset('assets/whoosh.mp3'),
    syncToAnchor: 'title_reveal',
    volume: 0.8,
  ),

  // Impact at number reveal
  AudioTrack(
    source: AudioSource.asset('assets/impact.mp3'),
    syncToAnchor: 'number_reveal',
    volume: 0.9,
  ),

  // Celebration at end
  AudioTrack(
    source: AudioSource.asset('assets/celebration.mp3'),
    syncToAnchor: 'finale',
    volume: 0.7,
  ),
]
```

---

## Examples

### Beat-Synced Animation

Sync visual animations to music beats:

```dart
final beatFrames = [0, 30, 60, 90, 120, 150];  // Every second at 30fps

Video(
  fps: 30,
  scenes: [
    Scene(
      durationInFrames: 180,
      children: [
        // Pulsing element on each beat
        TimeConsumer(
          builder: (context, frame, _) {
            final onBeat = beatFrames.contains(frame);
            final scale = onBeat ? 1.2 : 1.0;

            return Transform.scale(
              scale: scale,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan,
                ),
              ),
            );
          },
        ),

        // Sync anchors at each beat
        for (var i = 0; i < beatFrames.length; i++)
          SyncAnchor(
            id: 'beat_$i',
            frame: beatFrames[i],
            child: SizedBox.shrink(),
          ),
      ],
    ),
  ],
  audioTracks: [
    // Kick drum on each beat
    for (var i = 0; i < beatFrames.length; i++)
      AudioTrack(
        source: AudioSource.asset('assets/kick.mp3'),
        syncToAnchor: 'beat_$i',
        volume: 0.8,
      ),
  ],
)
```

### Countdown with Sound Effects

```dart
Scene(
  durationInFrames: 180,
  children: [
    // Countdown numbers
    ...[3, 2, 1].asMap().entries.map((entry) {
      final index = entry.key;
      final number = entry.value;
      final frame = index * 40;

      return SyncAnchor(
        id: 'count_$number',
        frame: frame,
        child: AnimatedProp(
          startFrame: frame,
          duration: 35,
          animation: PropAnimation.combine([
            PropAnimation.zoomIn(start: 2.0, end: 0.8),
            PropAnimation.fadeOut(),
          ]),
          child: Text(
            '$number',
            style: TextStyle(fontSize: 200, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }),

    // "GO!" at the end
    SyncAnchor(
      id: 'go',
      frame: 120,
      child: AnimatedProp(
        startFrame: 120,
        animation: PropAnimation.elasticPop(),
        child: Text('GO!', style: TextStyle(fontSize: 150)),
      ),
    ),
  ],
)
```

```dart
audioTracks: [
  AudioTrack(source: AudioSource.asset('assets/beep.mp3'), syncToAnchor: 'count_3'),
  AudioTrack(source: AudioSource.asset('assets/beep.mp3'), syncToAnchor: 'count_2'),
  AudioTrack(source: AudioSource.asset('assets/beep.mp3'), syncToAnchor: 'count_1'),
  AudioTrack(source: AudioSource.asset('assets/horn.mp3'), syncToAnchor: 'go'),
]
```

### Scene Transition Sounds

```dart
Video(
  scenes: [
    Scene(
      durationInFrames: 150,
      transitionOut: SceneTransition.slideLeft(durationInFrames: 20),
      children: [
        SyncAnchor(id: 'scene1_end', frame: 130, child: ...),
      ],
    ),
    Scene(
      durationInFrames: 150,
      transitionIn: SceneTransition.slideLeft(durationInFrames: 20),
      children: [
        SyncAnchor(id: 'scene2_start', frame: 0, child: ...),
      ],
    ),
  ],
  audioTracks: [
    AudioTrack(
      source: AudioSource.asset('assets/whoosh.mp3'),
      startFrame: 130,  // At transition
    ),
  ],
)
```

---

## Best Practices

### 1. Name Anchors Descriptively

```dart
// Good
SyncAnchor(id: 'title_reveal', ...)
SyncAnchor(id: 'beat_drop_1', ...)
SyncAnchor(id: 'confetti_burst', ...)

// Avoid
SyncAnchor(id: 'a1', ...)
SyncAnchor(id: 'sync', ...)
```

### 2. Start Audio Slightly Early

Human perception anticipates sound. Start audio 2-3 frames early:

```dart
SyncAnchor(id: 'visual', frame: 60, ...)

AudioTrack(
  syncToAnchor: 'visual',
  syncOffset: -2,  // 2 frames early
)
```

### 3. Test Audio Sync

Preview your composition to verify sync feels right. Visual and audio perception can vary.

### 4. Use Consistent Timing

If using beat-based sync, calculate frames consistently:

```dart
// 120 BPM at 30fps = 15 frames per beat
const bpm = 120;
const fps = 30;
const framesPerBeat = (60 / bpm * fps).round();  // 15

final beats = List.generate(8, (i) => i * framesPerBeat);
// [0, 15, 30, 45, 60, 75, 90, 105]
```

### 5. Don't Over-Sync

Not every visual element needs a sound. Over-syncing can feel cluttered.

---

## Related

- [Audio](../embedding/audio.md) - Audio embedding guide
- [TimeConsumer](../widgets/core/time-consumer.md) - Frame-based animation
- [Interpolate](../animations/interpolate.md) - Smooth value animation
