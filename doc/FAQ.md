# Frequently Asked Questions

## Installation & Setup

### Q: Why do I get "FFmpeg not found" errors?

**A:** Fluvie requires FFmpeg to be installed on your system. The package uses FFmpeg to encode the rendered frames into video files.

**Solutions:**
- **Linux**: `sudo apt install ffmpeg`
- **macOS**: `brew install ffmpeg`
- **Windows**: Download from [ffmpeg.org](https://ffmpeg.org/download.html) and add to PATH
- **Web**: Include FFmpeg.wasm scripts in your `web/index.html`

See [FFmpeg Setup Guide](getting-started/ffmpeg-setup.md) for detailed instructions.

### Q: Why does my video have black backgrounds?

**A:** Fluvie requires Flutter's **Impeller renderer** for proper video rendering. The Skia renderer causes black backgrounds and visual artifacts.

**Solution:**
```bash
flutter run --enable-impeller
```

For VS Code debugging, add to your `.vscode/launch.json`:
```json
{
  "configurations": [{
    "name": "Fluvie (Impeller)",
    "request": "launch",
    "type": "dart",
    "args": ["--enable-impeller"]
  }]
}
```

See [Impeller Requirements](../README.md#impeller-renderer-required) for more details.

### Q: How do I check if FFmpeg is installed correctly?

**A:** Use the built-in FFmpeg checker:

```dart
import 'package:fluvie/fluvie.dart';

final diagnostics = await FFmpegChecker.check();
if (!diagnostics.isAvailable) {
  print('FFmpeg not found: ${diagnostics.errorMessage}');
  print(diagnostics.installationInstructions);
} else {
  print('FFmpeg version: ${diagnostics.version}');
}
```

## Performance

### Q: Rendering is slow. How can I speed it up?

**A:** Try these optimization strategies:

1. **Reduce resolution**: 720p renders ~2x faster than 1080p
   ```dart
   VideoComposition(
     width: 1280,  // Instead of 1920
     height: 720,  // Instead of 1080
     // ...
   )
   ```

2. **Lower frame rate**: 24fps is ~20% faster than 30fps
   ```dart
   VideoComposition(
     fps: 24,  // Instead of 30
     // ...
   )
   ```

3. **Simplify effects**: Avoid expensive operations like blur and gradients in every frame

4. **Optimize widget tree**: Don't recreate identical widgets for each frame

5. **Use const widgets** where possible

See [Performance Optimization Guide](performance/optimization-guide.md) for more tips.

### Q: The app crashes during rendering. What's wrong?

**A:** Check these common issues:

1. **Memory usage**: Large compositions can use 1-2 GB of RAM
   - Solution: Reduce composition complexity or render in segments

2. **FFmpeg not properly installed**
   - Solution: Run `FFmpegChecker.check()` to diagnose

3. **Disk space**: Temporary files can be large
   - Solution: Ensure at least 2-5 GB free disk space

4. **Impeller not enabled**: Can cause rendering failures
   - Solution: Run with `--enable-impeller` flag

See [Troubleshooting Guide](troubleshooting.md) for more help.

### Q: How much memory does Fluvie use?

**A:** Memory usage depends on composition complexity:

| Composition Type | Peak Memory Usage |
|------------------|-------------------|
| Simple text-only | ~200 MB |
| Medium (images + text) | ~500 MB |
| Complex (video clips) | ~1.5 GB |

Tips to reduce memory:
- Render at lower resolution
- Use smaller image assets
- Limit simultaneous layers
- Render in shorter segments

## Features

### Q: Can I use custom fonts?

**A:** Yes! Use Flutter's standard font loading mechanism.

1. Add font to `pubspec.yaml`:
   ```yaml
   fonts:
     - family: MyCustomFont
       fonts:
         - asset: fonts/MyCustomFont-Regular.ttf
   ```

2. Use in your composition:
   ```dart
   Text(
     'Hello Fluvie!',
     style: TextStyle(
       fontFamily: 'MyCustomFont',
       fontSize: 48,
     ),
   )
   ```

See [Text Styling](widgets/text-widgets.md) for more examples.

### Q: How do I sync animations to audio beats?

**A:** Use `SyncAnchor` with BPM detection:

```dart
// 1. Add audio track with BPM
AudioTrack(
  source: AudioSource.asset('music.mp3'),
  bpm: 120,  // Beats per minute
)

// 2. Place sync anchors at beat intervals
SyncAnchor(
  id: 'beat_1',
  frame: 30,  // First beat
)

// 3. Reference in animations
TimeConsumer(
  builder: (context, frame, progress) {
    final beatProgress = context.getProgressSince('beat_1');
    // Animate based on beat progress
  },
)
```

See [Audio Sync Recipe](cookbook/audio-sync.md) for complete examples.

### Q: Can I generate videos on mobile (iOS/Android)?

**A:** Yes, but you need to provide a custom FFmpeg implementation using `ffmpeg_kit_flutter`.

Fluvie doesn't include FFmpeg binaries for mobile by default due to package size constraints.

**Setup:**
1. Add `ffmpeg_kit_flutter` to your `pubspec.yaml`
2. Implement custom `FFmpegProvider`
3. Register with `FFmpegProviderRegistry`

See [Mobile Setup Guide](platform_setup/mobile.md) for complete instructions.

### Q: Can I export to formats other than MP4?

**A:** Yes! Fluvie supports multiple output formats through FFmpeg:

- **MP4** (H.264): Best compatibility
- **WebM** (VP9): Web-optimized
- **GIF**: Animated images (lower quality)
- **MOV** (ProRes): High quality, large files

Specify format in render configuration:
```dart
final config = RenderConfig(
  // ... other config
  outputFormat: VideoFormat.webm,
);
```

### Q: Can I render videos without displaying a UI?

**A:** Yes! Fluvie can render headlessly in the background:

```dart
final service = RenderService();
await service.execute(
  config: config,
  repaintBoundaryKey: boundaryKey,
  onFrameUpdate: (frame) {
    print('Rendering frame $frame');
  },
  onComplete: (outputPath) {
    print('Video saved to: $outputPath');
  },
);
```

The UI preview is optional - only needed for interactive development.

## Troubleshooting

### Q: Videos are choppy or have artifacts

**A:** This usually indicates the Skia renderer is being used instead of Impeller.

**Solutions:**
1. **Enable Impeller**: Run with `flutter run --enable-impeller`
2. **Check renderer**: Fluvie will log a warning if Skia is detected
3. **Verify platform**: Impeller is default on iOS, but requires flag on desktop/Android

### Q: Audio is out of sync with video

**A:** Audio sync issues can occur due to frame rate mismatches.

**Solutions:**
1. **Match timeline FPS** to your audio sample rate expectations (usually 30fps or 60fps)
2. **Use exact frame counts** for audio track duration:
   ```dart
   AudioTrack(
     durationInFrames: timeline.durationInFrames,  // Match exactly
     // ...
   )
   ```
3. **Avoid variable frame rates** in your rendering

### Q: Colors look different in exported video vs preview

**A:** Color space differences between preview and export can cause this.

**Solutions:**
1. Ensure Impeller is enabled (consistent rendering)
2. Check FFmpeg color space settings
3. Use consistent color profiles in your assets

### Q: Text rendering looks blurry

**A:** Text can appear blurry if rendered at low resolution or scaled incorrectly.

**Solutions:**
1. **Increase composition resolution**:
   ```dart
   VideoComposition(
     width: 1920,  // Full HD
     height: 1080,
     // ...
   )
   ```

2. **Use appropriate font sizes**: Don't scale small text up
3. **Enable anti-aliasing** (enabled by default in Flutter)

### Q: "SharedArrayBuffer is not defined" error on web

**A:** Web builds require specific server headers for WASM FFmpeg.

**Solution:** Configure your server to send:
```
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Opener-Policy: same-origin
```

See [Web Setup Guide](platform_setup/web.md) for detailed instructions.

## Advanced Usage

### Q: Can I use custom FFmpeg filters?

**A:** Yes! For advanced users, you can extend the FFmpeg filter graph.

See [Custom Render Pipeline](advanced/custom-render-pipeline.md) for examples.

### Q: How do I batch generate multiple videos?

**A:** Create a loop that renders multiple compositions:

```dart
for (final config in videoConfigs) {
  await renderService.execute(
    config: config,
    // ...
  );
}
```

See [Batch Generation Recipe](cookbook/batch-generation.md) for complete example.

### Q: Can I cancel a render in progress?

**A:** Currently, Fluvie doesn't support cancellation mid-render. This is planned for a future release.

Workaround: Run renders in isolates and terminate the isolate if needed.

## Getting Help

### Still having issues?

- **Documentation**: Browse the [full documentation](.)
- **Examples**: Check the [example gallery](../example/)
- **GitHub Issues**: [Report bugs or request features](https://github.com/simonerich/fluvie/issues)
- **Discussions**: [Ask questions on GitHub Discussions](https://github.com/simonerich/fluvie/discussions)

---

**Can't find your question?** [Open a discussion](https://github.com/simonerich/fluvie/discussions/new) and we'll add it to this FAQ!
