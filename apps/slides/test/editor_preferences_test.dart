import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/editor_screen.dart';

import 'desktop_surface.dart';
import 'memory_autosave_store.dart';

final class _DelayedSettings extends OiSettingsDriver {
  final pending = <Completer<void>>[];
  final writes = <Map<String, dynamic>>[];
  Map<String, dynamic>? saved;
  @override
  Future<T?> load<T extends OiSettingsData>({
    required String namespace,
    required T Function(Map<String, dynamic>) deserialize,
    String? key,
  }) async => key == 'view' && saved != null ? deserialize(saved!) : null;
  @override
  Future<void> save<T extends OiSettingsData>({
    required String namespace,
    required T data,
    required Map<String, dynamic> Function(T) serialize,
    String? key,
  }) async {
    if (key != 'view') return;
    final value = serialize(data);
    writes.add(value);
    final gate = Completer<void>();
    pending.add(gate);
    await gate.future;
    saved = value;
  }

  @override
  Future<void> delete({required String namespace, String? key}) async => saved = null;
  @override
  Future<bool> exists({required String namespace, String? key}) async => saved != null;
}

void main() {
  testWidgets('preference writes stay ordered after a failed save and restore on reopen', (
    tester,
  ) async {
    useDesktopSurface(tester);
    final settings = _DelayedSettings();
    final document = EditorDocument.fromJson(const {
      'fluvieSpec': 1,
      'scenes': [
        {'duration': '1s', 'children': <Object?>[]},
      ],
    });
    Widget editor() => OiApp(
      home: EditorScreen(
        key: UniqueKey(),
        document: document,
        title: 'preferences',
        onClose: () {},
        layoutSettings: settings,
        autosave: MemoryAutosaveStore(),
      ),
    );
    await tester.pumpWidget(editor());
    await tester.pump();
    void choose(EditorWorkspace workspace) =>
        tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).onChanged(workspace);
    choose(EditorWorkspace.quick);
    choose(EditorWorkspace.colour);
    choose(EditorWorkspace.deliver);
    await tester.pump();
    expect(settings.writes, hasLength(1), reason: 'A slow store must never race newer choices');
    settings.pending.first.completeError(StateError('Temporary storage failure'));
    await tester.pump();
    expect(settings.writes, hasLength(2));
    settings.pending[1].complete();
    await tester.pump();
    expect(settings.writes, hasLength(3));
    settings.pending[2].complete();
    await tester.pump();
    await tester.pumpWidget(editor());
    await tester.pump();
    expect(
      tester.widget<WorkspaceControl>(find.byType(WorkspaceControl)).workspace,
      EditorWorkspace.deliver,
    );
    expect(
      tester.widget<EditorCanvas>(find.byType(EditorCanvas)).document.toJson(),
      document.toJson(),
    );
    expect(tester.takeException(), isNull);
  });
}
