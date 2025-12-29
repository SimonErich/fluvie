import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'example_base.dart';

// Beginner examples
import 'examples_v2/beginner/hello_fluvie.dart';
import 'examples_v2/beginner/simple_slideshow.dart';
import 'examples_v2/beginner/text_animations_showcase.dart';

// Intermediate examples
import 'examples_v2/intermediate/motion_graphics_demo.dart';
import 'examples_v2/intermediate/layered_composition.dart';
import 'examples_v2/intermediate/entry_effects_gallery.dart';
// import 'examples_v2/intermediate/particle_wonderland.dart';
import 'examples_v2/intermediate/data_visualization.dart';
// import 'examples_v2/intermediate/audio_reactive_basics.dart';
import 'examples_v2/intermediate/template_sampler.dart';

// Advanced examples
// import 'examples_v2/advanced/embedded_video_mastery.dart';
import 'examples_v2/advanced/advanced_showcase.dart';

/// Provider for the current selected example
final selectedExampleProvider = StateProvider<VideoExample?>((ref) => null);

/// List of all available interactive examples
final List<InteractiveExample> allInteractiveExamples = [
  // Beginner examples
  HelloFluvieExample(),
  SimpleSlideshowExample(),
  TextAnimationsShowcaseExample(),

  // Intermediate examples
  MotionGraphicsDemoExample(),
  LayeredCompositionExample(),
  EntryEffectsGalleryExample(),
  // ParticleWonderlandExample(),
  DataVisualizationExample(),
  // AudioReactiveBasicsExample(),
  TemplateSamplerExample(),

  // Advanced examples
  // EmbeddedVideoMasteryExample(),
  AdvancedShowcaseExample(),
];

/// Widget that displays the gallery drawer
class ExampleGalleryDrawer extends StatelessWidget {
  final VideoExample? selectedExample;
  final Function(VideoExample) onExampleSelected;

  const ExampleGalleryDrawer({
    super.key,
    required this.selectedExample,
    required this.onExampleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fluvie Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Video Examples',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          ...allInteractiveExamples.map((example) {
            final isSelected = selectedExample?.title == example.title;
            return ListTile(
              selected: isSelected,
              leading: Icon(
                Icons.play_circle_outline,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              title: Text(example.title),
              subtitle: Text(
                example.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                onExampleSelected(example);
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}

/// Widget that displays example details
class ExampleDetails extends StatelessWidget {
  final VideoExample example;

  const ExampleDetails({super.key, required this.example});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              example.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              example.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: example.features.map((feature) {
                return Chip(
                  label: Text(feature),
                  backgroundColor: Colors.blue[50],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
