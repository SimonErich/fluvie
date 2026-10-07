import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  ToolState state() => container.read(toolProvider);
  ToolController controller() => container.read(toolProvider.notifier);

  test('select is the default tool', () {
    expect(state().tool, EditorTool.select);
  });

  test('activate switches tools; reset returns to select', () {
    controller().activate(EditorTool.text);
    expect(state().tool, EditorTool.text);
    controller().reset();
    expect(state().tool, EditorTool.select);
  });

  test('picking a shape variant activates the shape tool', () {
    controller().pickShape(ShapeVariant.ellipse);
    expect(state().tool, EditorTool.shape);
    expect(state().shape, ShapeVariant.ellipse);
  });

  test('the letter shortcuts map to their tools', () {
    expect(ToolController.toolForKey(LogicalKeyboardKey.keyV), const ToolState.select());
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyH),
      const ToolState(tool: EditorTool.hand),
    );
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyT),
      const ToolState(tool: EditorTool.text),
    );
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyR),
      const ToolState(tool: EditorTool.shape),
    );
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyO),
      const ToolState(tool: EditorTool.shape, shape: ShapeVariant.ellipse),
    );
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyL),
      const ToolState(tool: EditorTool.shape, shape: ShapeVariant.line),
    );
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyA),
      const ToolState(tool: EditorTool.shape, shape: ShapeVariant.arrow),
    );
    expect(
      ToolController.toolForKey(LogicalKeyboardKey.keyM),
      const ToolState(tool: EditorTool.media),
    );
    expect(ToolController.toolForKey(LogicalKeyboardKey.keyZ), isNull);
  });

  test('applying a key state mutates the provider', () {
    controller().apply(ToolController.toolForKey(LogicalKeyboardKey.keyR)!);
    expect(state().tool, EditorTool.shape);
    expect(state().shape, ShapeVariant.rectangle);
  });
  stateEqualitySuite();
}

// ToolState equality backs the provider's change detection.
void stateEqualitySuite() {
  test('ToolState compares by tool and shape', () {
    // ignore: prefer_const_constructors, a const pair would be identical and never run ==.
    final state = ToolState(tool: EditorTool.shape, shape: ShapeVariant.line);
    expect(state, const ToolState(tool: EditorTool.shape, shape: ShapeVariant.line));
    expect(
      state.hashCode,
      const ToolState(tool: EditorTool.shape, shape: ShapeVariant.line).hashCode,
    );
    expect(state, isNot(const ToolState(tool: EditorTool.shape)));
    expect(state.toString(), contains('shape'));
  });
}
