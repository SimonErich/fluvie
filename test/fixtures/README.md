# Test Fixtures

This directory contains test fixtures for the fluvie test suite.

## Directory Structure

```
fixtures/
├── audio/       # Audio files for testing BPM detection, frequency analysis
├── videos/      # Video files for testing embedded video, probing
├── images/      # Image files for testing templates with images
└── README.md    # This file
```

## Required Fixtures

### Audio (`audio/`)

| File | Description | Required For |
|------|-------------|--------------|
| `120bpm_synthetic.wav` | Synthetic 120 BPM metronome | BPM detection accuracy test |
| `90bpm_music.mp3` | Music file at ~90 BPM | Real-world BPM detection |
| `frequency_sweep.wav` | 20Hz-20kHz frequency sweep | Frequency analyzer tests |
| `silent.wav` | Silent audio file (1 second) | Edge case testing |
| `bass_heavy.mp3` | Bass-dominant audio | Frequency band tests |

### Videos (`videos/`)

| File | Description | Required For |
|------|-------------|--------------|
| `sample_480p.mp4` | Small test video (480p, ~2 seconds) | VideoProbeService tests |
| `with_audio.mp4` | Video with audio track | Embedded video audio extraction |

### Images (`images/`)

| File | Description | Required For |
|------|-------------|--------------|
| `test_image.png` | Generic test image (1080x1080) | Template image tests |
| `test_logo.png` | Small logo image (256x256) | Template logo tests |

## Generating Synthetic Audio

Use FFmpeg to generate test audio files:

```bash
# Generate 120 BPM metronome (click every 0.5 seconds)
ffmpeg -f lavfi -i "sine=frequency=1000:duration=0.05" -af "aloop=loop=-1:size=22050" -t 5 120bpm_synthetic.wav

# Generate frequency sweep
ffmpeg -f lavfi -i "sine=frequency=20:duration=10" -af "vibrato=f=1000:d=1" frequency_sweep.wav

# Generate silent audio
ffmpeg -f lavfi -i "anullsrc=r=44100:cl=mono" -t 1 silent.wav
```

## Generating Test Videos

```bash
# Generate simple test video (color bars)
ffmpeg -f lavfi -i "testsrc=duration=2:size=854x480:rate=30" -c:v libx264 -pix_fmt yuv420p sample_480p.mp4

# Generate video with audio
ffmpeg -f lavfi -i "testsrc=duration=3:size=854x480:rate=30" -f lavfi -i "sine=frequency=440:duration=3" -c:v libx264 -c:a aac -pix_fmt yuv420p with_audio.mp4
```

## Generating Test Images

```bash
# Generate solid color test image
ffmpeg -f lavfi -i "color=c=blue:size=1080x1080:duration=1" -frames:v 1 test_image.png

# Generate gradient test logo
ffmpeg -f lavfi -i "color=c=red:size=256x256:duration=1" -frames:v 1 test_logo.png
```

## Notes

- Keep fixture files small to minimize repo size
- Use lossless formats (WAV, PNG) for test accuracy where needed
- Use compressed formats (MP3, MP4) for real-world scenario testing
- All audio should be at 44100 Hz sample rate for consistency
- All video should be at 30 FPS for consistency with default fluvie settings
