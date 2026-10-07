// The codegen entrypoint exists so a WEB app (the slides editor's Dart
// export) can reach the pure printer without the main barrel's dart:ffi
// and dart:io surface. Everything it exports must stay platform-free.
import 'package:fluvie_cli/codegen.dart';
import 'package:test/test.dart';

void main() {
  test('the codegen entrypoint exposes the printer', () {
    final source = printVideoSpecJson({
      'fluvieSpec': 1,
      'size': {'width': 320, 'height': 180},
      'fps': 30,
      'scenes': [
        {'duration': '30f', 'children': <Object?>[]},
      ],
    });
    expect(source, contains('Video build()'));
  });
}
