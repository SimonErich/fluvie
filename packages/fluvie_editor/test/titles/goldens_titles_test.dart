@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Future<void> main() async {
  final fixtures = Directory('assets/titles').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  await goldenTest(
    'all bundled title compositions have visible editable headlines',
    fileName: 'title_compositions',
    builder: () => GoldenTestGroup(
      columns: 2,
      children: [
        for (final file in fixtures)
          GoldenTestScenario(
            name: file.uri.pathSegments.last,
            child: SizedBox(
              width: 320,
              height: 180,
              child: FittedBox(
                child: SizedBox(
                  width: 640,
                  height: 360,
                  child: Builder(
                    builder: (_) {
                      final template = TitleTemplate.fromJson(
                        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
                      );
                      final initial = EditorDocument.fromJson(const {
                        'fluvieSpec': 1,
                        'size': {'width': 640, 'height': 360},
                        'fps': 30,
                        'scenes': [
                          {'duration': '120f', 'children': <Object?>[]},
                        ],
                      });
                      final doc = InsertTitleCommand(
                        scene: 0,
                        title: template.prepare(initial, 0, 0),
                      ).apply(initial);
                      return RenderControllerScope(
                        controller: RenderController(initialFrame: 60),
                        child: doc.spec.build(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
