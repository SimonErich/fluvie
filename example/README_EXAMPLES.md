# Fluvie Interactive Example Gallery

## 🎉 Gallery Overview

An interactive showcase of Fluvie's video composition capabilities featuring **9 complete examples** across 3 difficulty levels, all with live parameter editing and real-time preview.

## 🚀 Quick Start

```bash
cd example
flutter run -d linux  # or macos, windows
```

The gallery will launch with an interactive 3-panel interface:
- **Left Panel**: Live video preview with frame scrubber
- **Center Panel**: Syntax-highlighted source code
- **Right Panel**: Interactive parameter controls

## 📚 Example Catalog

### Beginner Examples (3)

#### 1. Hello Fluvie
**File**: `lib/gallery/examples_v2/beginner/hello_fluvie.dart`
**Duration**: 90 frames (3 seconds @ 30fps)
**Features**: Basic Video, Scene, AnimatedText.slideUpFade, Background.gradient

The simplest possible Fluvie video - animated text with a gradient background.

**Parameters**:
- Duration (60-180 frames)
- Text content
- Font size (32-96)
- Gradient start/end colors
- Animation easing curve

#### 2. Simple Slideshow
**File**: `lib/gallery/examples_v2/beginner/simple_slideshow.dart`
**Duration**: 3 scenes, each 60-180 frames
**Features**: Multiple scenes, SceneTransition.crossFade, Background.solid

Multi-scene video demonstrating smooth transitions between colored scenes.

**Parameters**:
- Scene duration
- Transition duration (15-60 frames)
- Transition type (crossFade/none)
- 3 scene colors

#### 3. Text Animations Showcase
**File**: `lib/gallery/examples_v2/beginner/text_animations_showcase.dart`
**Duration**: 150 frames (5 seconds)
**Features**: TypewriterText, CounterText, AnimatedText variants

Side-by-side comparison of three different text animation types.

**Parameters**:
- Typewriter speed (5-30 chars/sec)
- Counter target value (100-9999)
- Animation style (slideUpFade, scaleFade, fadeIn)

### Intermediate Examples (5)

#### 4. Motion Graphics Demo
**File**: `lib/gallery/examples_v2/intermediate/motion_graphics_demo.dart`
**Duration**: 150 frames
**Features**: PropAnimation.combine, translate, rotate, scale, fade, VStack

Animated shapes with combined transformations creating complex motion graphics.

**Parameters**:
- Shape count (3-8)
- Animation duration (30-120 frames)
- Easing curve (linear, easeInOut, elasticOut)
- Primary color

**Demonstrates**: Combining multiple property animations (translate + rotate + scale + fade) with staggered timing.

#### 5. Layered Composition
**File**: `lib/gallery/examples_v2/intermediate/layered_composition.dart`
**Duration**: 180 frames
**Features**: VStack, Stagger, depth through layering

Multiple layers with staggered animations creating sense of depth.

**Parameters**:
- Layer count (2-6)
- Stagger delay (3-15 frames)
- Accent color

**Demonstrates**: Using stagger delay and size/opacity variations to create 3D depth perception.

#### 6. Entry Effects Gallery
**File**: `lib/gallery/examples_v2/intermediate/entry_effects_gallery.dart`
**Duration**: 150 frames
**Features**: AnimatedProp, VRow, multiple entry effects

Side-by-side showcase of 5 different entry animation styles.

**Parameters**:
- Animation duration (20-90 frames)
- Easing curve (easeOut, bounceOut, elasticOut)

**Demonstrates**: Slide Up, Slide Down, Scale, Rotate, and Fade entry effects compared simultaneously.

#### 7. Data Visualization
**File**: `lib/gallery/examples_v2/intermediate/data_visualization.dart`
**Duration**: 150 frames
**Features**: CounterText, animated progress bars, Stagger

Statistics dashboard with animated counters and progress indicators.

**Parameters**:
- 3 metric target values (100-9999 each)

**Demonstrates**: Creating engaging data presentations with animated numbers and bars.

#### 8. Template Sampler
**File**: `lib/gallery/examples_v2/intermediate/template_sampler.dart`
**Duration**: 150 frames
**Features**: Template widgets, pre-built layouts

Showcase of Fluvie's template system with card-based layouts.

**Parameters**:
- Card title text
- Card subtitle text
- Accent color

**Demonstrates**: Using pre-built template components for faster video creation.

### Advanced Examples (1)

#### 9. Advanced Showcase
**File**: `lib/gallery/examples_v2/advanced/advanced_showcase.dart`
**Duration**: 270 frames (3 scenes @ 90 frames each)
**Features**: Multi-scene composition, scene transitions, all widgets combined

Complete production-quality video with 3 distinct scenes:
1. **Title Scene**: Animated background particles + brand intro
2. **Features Scene**: Staggered feature cards with icons
3. **Stats Scene**: Dashboard with counters

**Parameters**:
- Project name
- Tagline text
- Brand color (affects all scenes)

**Demonstrates**: Building complete videos with scene transitions, combining all intermediate techniques into a cohesive piece.

## 🎨 Gallery Features

### Interactive Parameter System
- **Sliders**: Numeric values with min/max ranges
- **Color Pickers**: Full color selection with preview
- **Dropdowns**: Predefined options with descriptions
- **Text Inputs**: Free-form text entry
- **Checkboxes**: Boolean toggles

### Live Preview
- Frame-by-frame scrubber (0-100% progress)
- Play/pause controls
- First/last frame jumps
- Previous/next frame stepping
- Real-time parameter updates

### Code Viewer
- Syntax-highlighted source code
- Toggle between Code and Instructions views
- Copy to clipboard functionality
- Shows complete example implementation

### Responsive Design
- **Desktop** (>1200px): 3-panel layout (20% preview | 50% code | 30% controls)
- **Tablet** (768-1200px): 2-panel layout (60% preview | 40% code+controls)
- **Mobile** (<768px): Tabbed interface

## 📖 Example Structure

Each example extends `InteractiveExample` and implements:

```dart
class MyExample extends InteractiveExample {
  @override
  String get title => 'Example Title';

  @override
  String get description => 'Short description';

  @override
  String get difficulty => 'Beginner'; // or Intermediate, Advanced

  @override
  String get category => 'Category Name';

  @override
  List<String> get features => ['Feature1', 'Feature2'];

  @override
  List<ExampleParameter> get parameters => [
    ExampleParameter.slider(...),
    ExampleParameter.color(...),
    // etc.
  ];

  @override
  List<String> get instructions => [
    'Step-by-step explanation...',
  ];

  @override
  Widget buildWithParameters(Map<String, dynamic> params) {
    // Extract parameters
    final duration = (params['duration'] as num).toInt();

    // Build video composition
    return Video(
      width: 1920,
      height: 1080,
      fps: 30,
      scenes: [...],
    );
  }

  @override
  String get sourceCode => '''
    // Simplified source code for display
  ''';
}
```

## 🔧 Technical Details

### Code Quality
- ✅ All examples compile without errors
- ✅ Proper use of Fluvie declarative API
- ✅ Consistent naming conventions
- ✅ Comprehensive parameter validation
- ✅ Responsive to all screen sizes

### API Usage
Examples demonstrate correct usage of:
- `durationInFrames: int` (not Duration objects)
- `children: []` in Scene (not builder callbacks)
- `colors: {frame: Color}` in Background.gradient (Map format)
- `PropAnimation.combine([...])` for complex animations
- `Stagger` with `staggerDelay` parameter
- `AnimatedProp` for applying animations
- Scene transitions (`transitionOut`, `transitionIn`)

### File Organization
```
lib/gallery/
├── example_base.dart              # Base classes
├── example_gallery.dart           # Registry
├── models/
│   └── example_parameter.dart     # Parameter system
├── showcase/
│   ├── showcase_page.dart         # Main UI
│   ├── preview_panel.dart         # Live preview
│   ├── code_viewer_panel.dart     # Code display
│   ├── controls_panel.dart        # Parameter controls
│   └── parameter_widgets/         # 5 widget types
└── examples_v2/
    ├── beginner/                  # 3 examples
    ├── intermediate/              # 5 examples
    └── advanced/                  # 1 example
```

## 📊 Statistics

- **Total Examples**: 9
- **Total Code**: ~4,100 lines
  - Examples: ~2,600 lines
  - Gallery UI: ~1,500 lines
- **Categories**: 3 (Beginner, Intermediate, Advanced)
- **Parameter Types**: 5 (slider, color, dropdown, text, checkbox)
- **Features Demonstrated**: 20+ unique Fluvie widgets
- **Compilation Status**: ✅ Zero errors

## 🎯 Learning Path

**Recommended order for learning**:

1. **Hello Fluvie** - Understand basic structure
2. **Simple Slideshow** - Learn multi-scene composition
3. **Text Animations Showcase** - Explore text widgets
4. **Entry Effects Gallery** - Master entry animations
5. **Motion Graphics Demo** - Combine animations
6. **Layered Composition** - Create depth
7. **Data Visualization** - Work with data
8. **Template Sampler** - Use templates
9. **Advanced Showcase** - Put it all together

## 💡 Tips for Creating Examples

1. **Start Simple**: Begin with single-scene compositions
2. **Use Parameters**: Make examples interactive and educational
3. **Add Instructions**: Explain what's happening step-by-step
4. **Show Source Code**: Provide simplified code snippets
5. **Test Thoroughly**: Verify all parameter combinations work
6. **Follow Patterns**: Match existing example structure

## 🐛 Known Issues

- Integration test references old FlutterVienna example (2 warnings)
  - File: `integration_test/render_flutter_vie_review_test.dart`
  - Impact: None on gallery functionality
  - Fix: Delete or update integration test

## 🚀 Next Steps

### Optional Additions (Not Required)
- Particle Wonderland example
- Audio-Reactive Basics example (requires audio file)
- Year in Review example (requires audio files)
- Individual markdown documentation per example
- Audio attribution file
- Keyboard shortcuts
- Search/filter in drawer

### Current Status
The gallery is **fully functional** and production-ready with 9 complete, high-quality examples demonstrating all core Fluvie features.

## 📝 License

Part of the Fluvie package. See LICENSE file in the root directory.
