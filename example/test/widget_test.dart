import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/main.dart';
import 'package:fluvie_example/gallery/example_gallery.dart';
import 'package:fluvie_example/gallery/example_base.dart';
import 'package:fluvie_example/gallery/models/example_parameter.dart';

void main() {
  group('MyApp', () {
    testWidgets('builds without error', (WidgetTester tester) async {
      // Use a large surface to avoid overflow issues
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Ignore overflow errors for this test
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) return;
        FlutterError.presentError(details);
      };

      await tester.pumpWidget(const ProviderScope(child: MyApp()));
      await tester.pump();

      // App should build successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('has correct title in theme', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Fluvie Interactive Gallery');
    });

    testWidgets('disables debug banner', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.debugShowCheckedModeBanner, false);
    });
  });

  group('ExampleGalleryDrawer', () {
    testWidgets('displays drawer header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: ExampleGalleryDrawer(
              selectedExample: null,
              onExampleSelected: (_) {},
            ),
          ),
        ),
      );

      // Open the drawer
      await tester.dragFrom(
        tester.getTopLeft(find.byType(Scaffold)),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fluvie Gallery'), findsOneWidget);
      expect(find.text('Video Examples'), findsOneWidget);
    });

    testWidgets('lists all examples', (WidgetTester tester) async {
      // Set larger size to show all items
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: ExampleGalleryDrawer(
              selectedExample: null,
              onExampleSelected: (_) {},
            ),
          ),
        ),
      );

      // Open the drawer
      await tester.dragFrom(
        tester.getTopLeft(find.byType(Scaffold)),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      // Should have ListTile for each example
      expect(
        find.byType(ListTile),
        findsNWidgets(allInteractiveExamples.length),
      );
    });

    testWidgets('highlights selected example', (WidgetTester tester) async {
      final example = allInteractiveExamples.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: ExampleGalleryDrawer(
              selectedExample: example,
              onExampleSelected: (_) {},
            ),
          ),
        ),
      );

      // Open the drawer
      await tester.dragFrom(
        tester.getTopLeft(find.byType(Scaffold)),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      // Find the selected ListTile
      final selectedTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, example.title),
      );
      expect(selectedTile.selected, true);
    });

    testWidgets('calls onExampleSelected when tapped',
        (WidgetTester tester) async {
      VideoExample? selectedExample;
      final example = allInteractiveExamples.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: ExampleGalleryDrawer(
              selectedExample: null,
              onExampleSelected: (e) => selectedExample = e,
            ),
          ),
        ),
      );

      // Open the drawer
      await tester.dragFrom(
        tester.getTopLeft(find.byType(Scaffold)),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();

      // Tap on the first example
      await tester.tap(find.text(example.title));
      await tester.pumpAndSettle();

      expect(selectedExample?.title, example.title);
    });
  });

  group('ExampleDetails', () {
    testWidgets('displays example title', (WidgetTester tester) async {
      final example = allInteractiveExamples.first;

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ExampleDetails(example: example))),
      );

      expect(find.text(example.title), findsOneWidget);
    });

    testWidgets('displays example description', (WidgetTester tester) async {
      final example = allInteractiveExamples.first;

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ExampleDetails(example: example))),
      );

      expect(find.text(example.description), findsOneWidget);
    });

    testWidgets('displays feature chips', (WidgetTester tester) async {
      final example = allInteractiveExamples.first;

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ExampleDetails(example: example))),
      );

      // Should find Chip widgets for each feature
      expect(find.byType(Chip), findsNWidgets(example.features.length));
    });
  });

  group('ExampleParameter', () {
    test('slider factory creates correct parameter', () {
      final param = ExampleParameter.slider(
        id: 'test',
        label: 'Test',
        description: 'A test parameter',
        defaultValue: 50,
        minValue: 0,
        maxValue: 100,
      );

      expect(param.type, ParameterType.slider);
      expect(param.id, 'test');
      expect(param.label, 'Test');
      expect(param.description, 'A test parameter');
      expect(param.defaultValue, 50);
      expect(param.minValue, 0);
      expect(param.maxValue, 100);
    });

    test('color factory creates correct parameter', () {
      final param = ExampleParameter.color(
        id: 'color',
        label: 'Color',
        description: 'A color parameter',
        defaultValue: Colors.red,
      );

      expect(param.type, ParameterType.colorPicker);
      expect(param.defaultValue, Colors.red);
    });

    test('dropdown factory creates correct parameter', () {
      final param = ExampleParameter.dropdown(
        id: 'dropdown',
        label: 'Dropdown',
        description: 'A dropdown parameter',
        defaultValue: 'option1',
        options: [
          const DropdownOption(value: 'option1', label: 'Option 1'),
          const DropdownOption(value: 'option2', label: 'Option 2'),
        ],
      );

      expect(param.type, ParameterType.dropdown);
      expect(param.defaultValue, 'option1');
      expect(param.options?.length, 2);
    });

    test('text factory creates correct parameter', () {
      final param = ExampleParameter.text(
        id: 'text',
        label: 'Text',
        description: 'A text parameter',
        defaultValue: 'Hello',
      );

      expect(param.type, ParameterType.text);
      expect(param.defaultValue, 'Hello');
    });

    test('checkbox factory creates correct parameter', () {
      final param = ExampleParameter.checkbox(
        id: 'checkbox',
        label: 'Checkbox',
        description: 'A checkbox parameter',
        defaultValue: true,
      );

      expect(param.type, ParameterType.checkbox);
      expect(param.defaultValue, true);
    });
  });

  group('DropdownOption', () {
    test('stores value and label', () {
      const option = DropdownOption(
        value: 'test_value',
        label: 'Test Label',
        description: 'Optional description',
      );

      expect(option.value, 'test_value');
      expect(option.label, 'Test Label');
      expect(option.description, 'Optional description');
    });
  });

  group('allInteractiveExamples', () {
    test('contains examples', () {
      expect(allInteractiveExamples, isNotEmpty);
    });

    test('all examples have required properties', () {
      for (final example in allInteractiveExamples) {
        expect(example.title, isNotEmpty);
        expect(example.description, isNotEmpty);
        expect(example.features, isNotEmpty);
        expect(example.difficulty, isNotEmpty);
        expect(example.category, isNotEmpty);
        expect(example.sourceCode, isNotEmpty);
        expect(example.instructions, isNotEmpty);
      }
    });

    test('all examples can build composition', () {
      for (final example in allInteractiveExamples) {
        final widget = example.buildComposition();
        expect(widget, isA<Widget>());
      }
    });

    test('all examples can provide config', () {
      for (final example in allInteractiveExamples) {
        final config = example.getConfig();
        expect(config.timeline.fps, greaterThan(0));
        expect(config.timeline.width, greaterThan(0));
        expect(config.timeline.height, greaterThan(0));
        expect(config.timeline.durationInFrames, greaterThan(0));
      }
    });

    test('all examples have default parameters', () {
      for (final example in allInteractiveExamples) {
        final defaults = example.defaultParameters;
        expect(defaults.keys.length, example.parameters.length);

        // Each parameter should have its default in the map
        for (final param in example.parameters) {
          expect(defaults.containsKey(param.id), true);
          expect(defaults[param.id], param.defaultValue);
        }
      }
    });

    test('all examples can build with parameters', () {
      for (final example in allInteractiveExamples) {
        final widget = example.buildWithParameters(example.defaultParameters);
        expect(widget, isA<Widget>());
      }
    });
  });

  group('VideoExample base class', () {
    test('getConfig extracts from VideoComposition', () {
      final example = allInteractiveExamples.first;
      final config = example.getConfig();

      // Should return a valid config
      expect(config.timeline.fps, greaterThan(0));
    });
  });
}
