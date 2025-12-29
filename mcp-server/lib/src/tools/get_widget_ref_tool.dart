import '../mcp/mcp_types.dart';

/// Creates the getWidgetReference tool definition
ToolDefinition createGetWidgetReferenceTool() {
  return ToolDefinition(
    name: 'getWidgetReference',
    description:
        '''Get detailed documentation for a specific Fluvie widget including properties, examples, and related widgets.

Core widgets: Video, VideoComposition, Scene, Sequence, TimeConsumer
Layout widgets: LayerStack, Layer, VStack, VColumn, VRow, VCenter, VPadding, VSizedBox, VPositioned
Audio widgets: AudioTrack, AudioSource, BackgroundAudio, AudioReactive
Text widgets: FadeText, AnimatedText, TypewriterText, CounterText
Media widgets: EmbeddedVideo, VideoSequence, Collage, KenBurnsImage
Animation: AnimatedProp, PropAnimation, EntryAnimation, Stagger, StaggerConfig, FloatingElement
Effects: ParticleEffect, EffectOverlay, Background, SceneTransition
Helpers: PolaroidFrame, PhotoCard, StatCard''',
    inputSchema: {
      'type': 'object',
      'properties': {
        'widgetName': {
          'type': 'string',
          'description':
              'Name of the widget (e.g., "Video", "Scene", "VStack", "AnimatedText", "ParticleEffect")',
        },
      },
      'required': ['widgetName'],
    },
    handler: (args) async {
      final widgetName = args['widgetName'] as String;
      final widgetDoc = _getWidgetDocumentation(widgetName);

      if (widgetDoc == null) {
        return ToolResult(
          content: [
            TextContent(
              'Widget not found: $widgetName\n\n'
              'Available widgets:\n'
              '- Core: Video, VideoComposition, Scene, Sequence, TimeConsumer\n'
              '- Layout: LayerStack, Layer, VStack, VColumn, VRow, VCenter, VPadding, VSizedBox, VPositioned\n'
              '- Audio: AudioTrack, AudioSource, BackgroundAudio\n'
              '- Text: FadeText, AnimatedText, TypewriterText, CounterText\n'
              '- Media: EmbeddedVideo, KenBurnsImage, Collage\n'
              '- Animation: AnimatedProp, PropAnimation, StaggerConfig, FloatingElement\n'
              '- Effects: ParticleEffect, EffectOverlay, Background, SceneTransition\n'
              '- Helpers: PolaroidFrame, PhotoCard, StatCard\n\n'
              'Use searchDocs to find more widgets.',
            ),
          ],
          isError: true,
        );
      }

      return ToolResult(
        content: [TextContent(widgetDoc)],
      );
    },
  );
}

String? _getWidgetDocumentation(String widgetName) {
  final widgets = <String, String>{
    'Video': '''
# Video Widget

Root widget for video composition. Manages scenes, transitions, and audio.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fps` | `int` | **required** | Frames per second |
| `width` | `int` | **required** | Output width in pixels |
| `height` | `int` | **required** | Output height in pixels |
| `scenes` | `List<Scene>` | **required** | List of scenes in order |
| `encoding` | `EncodingConfig?` | `null` | Quality and format settings |
| `defaultTransition` | `SceneTransition?` | `null` | Transition between all scenes |
| `backgroundMusicAsset` | `String?` | `null` | Asset path for background music |
| `musicVolume` | `double` | `1.0` | Background music volume (0.0-1.0) |
| `musicFadeInFrames` | `int` | `0` | Frames to fade in music |
| `musicFadeOutFrames` | `int` | `0` | Frames to fade out music |

## Example

```dart
Video(
  fps: 30,
  width: 1080,
  height: 1920,
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
  scenes: [
    Scene(durationInFrames: 120, children: [...]),
    Scene(durationInFrames: 90, children: [...]),
  ],
)
```

## Related
- Scene, SceneTransition, EncodingConfig
''',
    'Scene': '''
# Scene Widget

Time-bounded section of video with background and content.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `durationInFrames` | `int` | **required** | Duration in frames |
| `background` | `Background?` | `null` | Scene background |
| `children` | `List<Widget>` | `[]` | Content widgets |
| `fadeInFrames` | `int` | `0` | Fade in duration |
| `fadeOutFrames` | `int` | `0` | Fade out duration |
| `transitionIn` | `SceneTransition?` | `null` | Entry transition |
| `transitionOut` | `SceneTransition?` | `null` | Exit transition |

## Example

```dart
Scene(
  durationInFrames: 120,
  background: Background.gradient(
    colors: {0: Color(0xFF1a1a2e), 120: Color(0xFF0f3460)},
  ),
  fadeInFrames: 20,
  children: [
    VCenter(child: AnimatedText.slideUpFade('Hello!')),
  ],
)
```

## Related
- Video, Background, SceneTransition
''',
    'AnimatedText': '''
# AnimatedText Widget

Text with built-in animations.

## Factory Constructors

- `AnimatedText.fadeIn()` - Fade from 0 to 1 opacity
- `AnimatedText.slideUpFade()` - Slide up while fading in
- `AnimatedText.scaleFade()` - Scale up while fading in
- `AnimatedText.slideUp()` - Slide up only

## Common Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | `String` | **required** | Text content |
| `startFrame` | `int` | `0` | When animation starts |
| `duration` | `int` | `30` | Animation duration in frames |
| `style` | `TextStyle?` | `null` | Text styling |

## Examples

```dart
AnimatedText.fadeIn(
  'Hello World',
  startFrame: 0,
  duration: 30,
  style: TextStyle(fontSize: 48, color: Colors.white),
)

AnimatedText.slideUpFade(
  'Animated Text',
  startFrame: 30,
  duration: 25,
  distance: 30,
  style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
)

AnimatedText.scaleFade(
  'Big Entry',
  startFrame: 0,
  duration: 30,
  startScale: 0.5,
)
```

## Related
- TypewriterText, CounterText, FadeText
''',
    'VCenter': '''
# VCenter Widget

Centers content with optional timing.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Content to center |
| `startFrame` | `int?` | `null` | When visible |
| `endFrame` | `int?` | `null` | When hidden |
| `fadeInFrames` | `int` | `0` | Fade in duration |
| `fadeOutFrames` | `int` | `0` | Fade out duration |

## Example

```dart
VCenter(
  startFrame: 30,
  fadeInFrames: 15,
  child: Text('Centered'),
)
```

## Related
- VPositioned, VColumn, VRow, VStack
''',
    'VPositioned': '''
# VPositioned Widget

Absolute positioning with timing and fade support.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Content to position |
| `top` | `double?` | `null` | Distance from top |
| `left` | `double?` | `null` | Distance from left |
| `right` | `double?` | `null` | Distance from right |
| `bottom` | `double?` | `null` | Distance from bottom |
| `startFrame` | `int?` | `null` | When visible |
| `endFrame` | `int?` | `null` | When hidden |
| `fadeInFrames` | `int` | `0` | Fade in duration |
| `fadeOutFrames` | `int` | `0` | Fade out duration |

## Example

```dart
VPositioned(
  top: 100,
  left: 50,
  right: 50,
  startFrame: 30,
  endFrame: 120,
  fadeInFrames: 15,
  child: Text('Positioned'),
)
```

## Related
- VCenter, VStack, LayerStack
''',
    'VColumn': '''
# VColumn Widget

Column with stagger animation support.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `children` | `List<Widget>` | **required** | Column children |
| `spacing` | `double` | `0` | Gap between children |
| `stagger` | `StaggerConfig?` | `null` | Stagger animation |
| `mainAxisAlignment` | `MainAxisAlignment` | `start` | Main axis alignment |
| `crossAxisAlignment` | `CrossAxisAlignment` | `center` | Cross axis alignment |

## Example

```dart
VColumn(
  spacing: 20,
  stagger: StaggerConfig.slideUp(delay: 10, duration: 30),
  children: [
    Text('Item 1'),  // Starts at frame 0
    Text('Item 2'),  // Starts at frame 10
    Text('Item 3'),  // Starts at frame 20
  ],
)
```

## Related
- VRow, StaggerConfig, VStack
''',
    'AnimatedProp': '''
# AnimatedProp Widget

Primary animation widget for property animations.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | Content to animate |
| `animation` | `PropAnimation` | **required** | Animation to apply |
| `duration` | `int` | **required** | Duration in frames |
| `startFrame` | `int` | `0` | When animation starts |
| `curve` | `Curve` | `linear` | Animation curve |

## Example

```dart
AnimatedProp(
  animation: PropAnimation.slideUpFade(),
  duration: 30,
  startFrame: 60,
  curve: Curves.easeOutCubic,
  child: Text('Animated'),
)

// Factory constructors
AnimatedProp.fadeIn(duration: 30, child: widget)
AnimatedProp.slideUp(duration: 30, child: widget)
AnimatedProp.zoomIn(duration: 30, child: widget)
```

## Related
- PropAnimation, TimeConsumer, StaggerConfig
''',
    'PropAnimation': '''
# PropAnimation

Animation definitions for transforms.

## Factory Constructors

### Basic
- `PropAnimation.translate(start, end)` - Move by offset
- `PropAnimation.scale(start, end)` - Scale up/down
- `PropAnimation.rotate(start, end)` - Rotate by radians
- `PropAnimation.fade(start, end)` - Change opacity

### Convenience
- `PropAnimation.slideUp(distance)` - Slide from below
- `PropAnimation.slideDown(distance)` - Slide from above
- `PropAnimation.zoomIn(start)` - Scale up
- `PropAnimation.fadeIn()` - Fade from 0 to 1
- `PropAnimation.slideUpFade(distance)` - Combined slide + fade

### Combined
- `PropAnimation.combine([...])` - Multiple animations

## Example

```dart
PropAnimation.combine([
  PropAnimation.slideUp(distance: 50),
  PropAnimation.fadeIn(),
  PropAnimation.zoomIn(start: 0.8),
])
```

## Related
- AnimatedProp, TimeConsumer
''',
    'ParticleEffect': '''
# ParticleEffect Widget

Animated particle systems.

## Factory Constructors

- `ParticleEffect.sparkles()` - Glittering star particles
- `ParticleEffect.confetti()` - Falling confetti
- `ParticleEffect.snow()` - Falling snowflakes
- `ParticleEffect.bubbles()` - Rising bubbles

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `count` | `int` | `25` | Number of particles |
| `color` | `Color?` | `null` | Particle color |
| `colors` | `List<Color>?` | `null` | Multiple colors |
| `randomSeed` | `int?` | `null` | For deterministic rendering |

## Example

```dart
ParticleEffect.sparkles(
  count: 25,
  color: Colors.yellow,
)

ParticleEffect.confetti(
  count: 40,
  colors: [Colors.red, Colors.blue, Colors.yellow],
)
```

## Related
- EffectOverlay, Background
''',
    'StatCard': '''
# StatCard Widget

Animated statistic display with counting animation.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `value` | `int` | **required** | Number to display |
| `label` | `String` | **required** | Label text |
| `sublabel` | `String?` | `null` | Secondary label |
| `color` | `Color` | **required** | Accent color |
| `startFrame` | `int` | `0` | When counting starts |
| `countDuration` | `int` | `60` | Counting animation duration |

## Factory Constructors

- `StatCard.percentage()` - Adds % suffix
- `StatCard.currency()` - Adds currency symbol

## Example

```dart
StatCard(
  value: 1234,
  label: 'PHOTOS',
  sublabel: 'This Year',
  color: Colors.blue,
  startFrame: 30,
  countDuration: 60,
)
```

## Related
- CounterText, AnimatedText
''',
    'EmbeddedVideo': '''
# EmbeddedVideo Widget

Video-in-video with frame synchronization.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `assetPath` | `String` | **required** | Path to video file |
| `width` | `double` | **required** | Display width |
| `height` | `double` | **required** | Display height |
| `startFrame` | `int` | `0` | When to show |
| `durationInFrames` | `int?` | `null` | How long to display |
| `trimStart` | `Duration?` | `null` | Skip from source start |
| `borderRadius` | `BorderRadius?` | `null` | Corner rounding |
| `includeAudio` | `bool` | `false` | Include video audio |
| `audioVolume` | `double` | `1.0` | Audio volume |

## Example

```dart
EmbeddedVideo(
  assetPath: 'assets/highlight.mp4',
  width: 900,
  height: 500,
  startFrame: 40,
  durationInFrames: 200,
  trimStart: Duration(seconds: 2),
  borderRadius: BorderRadius.circular(20),
  includeAudio: true,
  audioVolume: 1.0,
)
```

## Related
- KenBurnsImage, VideoSequence
''',
    'Background': '''
# Background

Scene background types.

## Factory Constructors

- `Background.solid(color)` - Solid color
- `Background.gradient(colors)` - Animated gradient
- `Background.image(assetPath)` - Image background
- `Background.noise(intensity)` - Noise texture
- `Background.vhs()` - VHS retro effect

## Example

```dart
// Solid color
Background.solid(Colors.black)

// Animated gradient (colors keyed by frame)
Background.gradient(
  colors: {
    0: Color(0xFF1a1a2e),
    60: Color(0xFF16213e),
    120: Color(0xFF0f3460),
  },
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

## Related
- Scene, EffectOverlay
''',
    'SceneTransition': '''
# SceneTransition

Transitions between scenes.

## Factory Constructors

- `SceneTransition.none()` - No transition
- `SceneTransition.crossFade(durationInFrames)` - Dissolve
- `SceneTransition.slideLeft(durationInFrames)` - Slide from right
- `SceneTransition.slideUp(durationInFrames)` - Slide from bottom
- `SceneTransition.scale(durationInFrames)` - Scale in
- `SceneTransition.wipe(durationInFrames, direction)` - Wipe
- `SceneTransition.zoomWarp(durationInFrames, maxZoom)` - Zoom effect
- `SceneTransition.colorBleed(durationInFrames)` - Color flow

## Example

```dart
Video(
  defaultTransition: const SceneTransition.crossFade(durationInFrames: 15),
  scenes: [...],
)

Scene(
  transitionIn: const SceneTransition.slideUp(durationInFrames: 20),
  transitionOut: const SceneTransition.crossFade(durationInFrames: 15),
  children: [...],
)
```

## Related
- Video, Scene
''',
    'TimeConsumer': '''
# TimeConsumer Widget

Provides current frame for custom animations. Rebuilds every frame.

## Builder Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | `BuildContext` | Build context |
| `frame` | `int` | Current frame number |
| `progress` | `double` | Progress 0.0-1.0 |

## Example

```dart
TimeConsumer(
  builder: (context, frame, progress) {
    final opacity = interpolate(frame, [0, 30], [0.0, 1.0]);
    return Opacity(opacity: opacity, child: Text('Fading in'));
  },
)
```

## Related
- AnimatedProp, interpolate()
''',
    'StaggerConfig': '''
# StaggerConfig

Configuration for staggered child animations.

## Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `delay` | `int` | **required** | Frames between each child |
| `duration` | `int` | **required** | Animation duration per child |
| `curve` | `Curve` | `easeOut` | Animation curve |
| `fadeIn` | `bool` | `true` | Include fade animation |
| `slideIn` | `bool` | `false` | Include slide animation |
| `slideOffset` | `Offset` | `Offset(0, 40)` | Slide distance |

## Factory Constructors

- `StaggerConfig.fade(delay, duration)`
- `StaggerConfig.slideUp(delay, duration, distance)`
- `StaggerConfig.scale(delay, duration, start)`
- `StaggerConfig.slideUpScale(delay, duration)`

## Example

```dart
VColumn(
  stagger: StaggerConfig.slideUp(delay: 10, duration: 30),
  children: [
    Text('Item 1'),
    Text('Item 2'),
    Text('Item 3'),
  ],
)
```

## Related
- VColumn, VRow, Stagger
''',
  };

  // Normalize widget name for lookup
  final normalized = widgetName.toLowerCase().replaceAll(' ', '');
  for (final entry in widgets.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }

  return null;
}
