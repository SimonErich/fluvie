// The editor shell: a resizable, persisted three-column stage with a bottom
// band that spans the whole surface. The band is where the timeline lives, and
// horizontal pixels are the scarcest thing in a timeline, so it must not be
// trapped inside the stage column the way it was.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';

/// An in-memory settings driver: the shell's persistence seam, so no test
/// touches real storage and a reopened shell can be asserted on.
final class _MemorySettings extends OiSettingsDriver {
  final Map<String, Map<String, dynamic>> saved = {};

  String _slot(String namespace, String? key) => '$namespace/${key ?? ''}';

  @override
  Future<T?> load<T extends OiSettingsData>({
    required String namespace,
    required T Function(Map<String, dynamic> json) deserialize,
    String? key,
  }) async {
    final json = saved[_slot(namespace, key)];
    return json == null ? null : deserialize(json);
  }

  @override
  Future<void> save<T extends OiSettingsData>({
    required String namespace,
    required T data,
    required Map<String, dynamic> Function(T value) serialize,
    String? key,
  }) async => saved[_slot(namespace, key)] = serialize(data);

  @override
  Future<void> delete({required String namespace, String? key}) async =>
      saved.remove(_slot(namespace, key));

  @override
  Future<bool> exists({required String namespace, String? key}) async =>
      saved.containsKey(_slot(namespace, key));
}

Widget _shell({
  OiSettingsDriver? settings,
  void Function(double left, double right)? onColumnWidths,
  bool withBand = true,
}) => OiApp(
  home: EditorShell(
    toolbar: const SizedBox(width: 48, child: Text('rail')),
    leftColumn: const Text('left'),
    stage: const Text('stage'),
    inspector: const Text('inspector'),
    bottom: withBand ? const Text('bottom') : null,
    settings: settings,
    onColumnWidths: onColumnWidths,
  ),
);

void main() {
  testWidgets('column widths persist and restore after the shell is remounted', (tester) async {
    final settings = _MemorySettings();
    await tester.pumpWidget(_shell(settings: settings));
    await tester.pumpAndSettle();
    final left = tester.getRect(find.text('left'));
    await tester.dragFrom(Offset(left.right + 1, left.center.dy), const Offset(45, 0));
    await tester.pumpAndSettle();
    final savedWidth = tester.getRect(find.text('left')).width;
    expect(settings.saved['fluvie.editor.shell/columns']?['left'], closeTo(savedWidth, 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_shell(settings: settings));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('left')).width, closeTo(savedWidth, 1));
  });

  testWidgets('mounts every slot it was given', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    for (final slot in ['rail', 'left', 'stage', 'inspector', 'bottom']) {
      expect(find.text(slot), findsOneWidget, reason: '$slot must mount');
    }
  });

  testWidgets('the bottom band spans everything but the tool rail', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    final shell = tester.getRect(find.byType(EditorShell));
    final rail = tester.getRect(find.text('rail'));
    final bottom = tester.getRect(find.byType(EditorShellBottomBand));

    // The whole point of the shell: a timeline gets the window's width rather
    // than whatever is left inside the stage column.
    expect(bottom.width, closeTo(shell.width - rail.width, 1));
    expect(bottom.left, closeTo(rail.right, 1));
  });

  testWidgets('the stage sits above the bottom band, not beside it', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('stage')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(EditorShellBottomBand)).top + 1),
    );
  });

  testWidgets('the inspector sits right of the stage, which sits right of left', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    final left = tester.getRect(find.text('left'));
    final stage = tester.getRect(find.text('stage'));
    final inspector = tester.getRect(find.text('inspector'));

    expect(left.right, lessThanOrEqualTo(stage.left + 1));
    expect(stage.right, lessThanOrEqualTo(inspector.left + 1));
  });

  testWidgets('a dragged divider persists its ratio for the next session', (tester) async {
    final settings = _MemorySettings();
    await tester.pumpWidget(_shell(settings: settings));
    await tester.pumpAndSettle();

    final band = tester.getRect(find.byType(EditorShellBottomBand));
    await tester.dragFrom(Offset(band.center.dx, band.top - 2), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(
      settings.saved,
      isNotEmpty,
      reason: 'the split has to survive a restart or every session re-arranges',
    );
  });

  testWidgets('with no driver the shell still lays out, it just forgets', (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    // The driver is a seam, not a requirement: a host that has nowhere to
    // persist still gets the layout.
    expect(find.byType(EditorShellBottomBand), findsOneWidget);
  });

  testWidgets('a resized column reports its width so the host can persist it', (tester) async {
    final widths = <(double, double)>[];
    await tester.pumpWidget(_shell(onColumnWidths: (l, r) => widths.add((l, r))));
    await tester.pumpAndSettle();

    final left = tester.getRect(find.text('left'));
    await tester.dragFrom(Offset(left.right + 1, left.center.dy), const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(widths, isNotEmpty);
  });

  testWidgets('a surface with no band gives the stage the whole height', (tester) async {
    // Master editing swaps the stage for a synthetic view that has no timeline.
    // Reserving a quarter of the height for an empty band would be worse than
    // not splitting at all.
    await tester.pumpWidget(_shell(withBand: false));
    await tester.pumpAndSettle();

    expect(find.byType(EditorShellBottomBand), findsNothing);
    expect(find.text('stage'), findsOneWidget);

    final shell = tester.getRect(find.byType(EditorShell));
    final stage = tester.getRect(find.text('stage'));
    expect(stage.height, closeTo(shell.height, 1));
  });
}
