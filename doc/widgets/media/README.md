# Media Widgets

Media widgets in Fluvie allow you to embed external videos and create photo collages within your video compositions.

## Overview

| Widget | Description | Use Case |
|--------|-------------|----------|
| [EmbeddedVideo](embedded-video.md) | Display video files in composition | Video clips, highlights |
| [VideoSequence](video-sequence.md) | Low-level video sequence | Custom video integration |
| [Collage](collage.md) | Arrange photos in layouts | Photo grids, galleries |

---

## Quick Examples

### Embedded Video

```dart
EmbeddedVideo(
  assetPath: 'assets/highlight.mp4',
  width: 900,
  height: 500,
  startFrame: 40,
  trimStart: Duration(seconds: 2),
  fit: BoxFit.cover,
  includeAudio: true,
)
```

### Photo Collage

```dart
Collage.grid2x2(
  spacing: 8,
  children: [
    Image.asset('photo1.jpg'),
    Image.asset('photo2.jpg'),
    Image.asset('photo3.jpg'),
    Image.asset('photo4.jpg'),
  ],
)
```

---

## Video Integration

Fluvie handles video embedding through frame extraction:

1. Video frames are extracted using FFmpeg
2. Frames are cached for smooth playback
3. Audio can be included in the final render
4. Timing is synchronized with the composition timeline

### Supported Formats

FFmpeg handles video decoding, so most formats are supported:
- MP4, MOV, AVI, MKV, WebM
- H.264, H.265, VP8, VP9

---

## Image Handling

Standard Flutter image widgets work in Fluvie:

```dart
// From assets
Image.asset('assets/photo.jpg', fit: BoxFit.cover)

// From network (cached)
Image.network('https://example.com/photo.jpg')

// From file
Image.file(File('/path/to/photo.jpg'))
```

For animated image effects, use helper widgets like:
- [KenBurnsImage](../helpers/ken-burns-image.md) - Pan and zoom effect
- [PhotoCard](../helpers/photo-card.md) - Styled photo frame
- [PolaroidFrame](../helpers/polaroid-frame.md) - Polaroid-style frame

### Flexible Image Sources

Fluvie helpers support both asset paths and custom widgets:

```dart
// Using child parameter (recommended - any image source)
KenBurnsImage(
  child: Image.network('https://example.com/photo.jpg', fit: BoxFit.cover),
  width: 800,
  height: 600,
)

PhotoCard(
  child: Image.network('https://example.com/photo.jpg', fit: BoxFit.cover),
  width: 400,
  height: 300,
)

// Using assetPath (legacy - local assets only)
KenBurnsImage(
  assetPath: 'assets/photo.jpg',
  width: 800,
  height: 600,
)
```

---

## Related

- [Embedding Videos](../../embedding/videos.md) - Detailed video guide
- [Embedding Images](../../embedding/images.md) - Image embedding guide
- [Helper Widgets](../helpers/README.md) - Photo helpers
