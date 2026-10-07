import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:fluvie_editor/src/commands/editor_clipboard.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';

part 'command_scope_value.dart';

void _noop() {}
void _ignoreIds(Set<String> ids) {}
void _ignoreSlide(int slide) {}
void _ignoreMaster(String name) {}
Rect? _noRect(String id) => null;

Size _canvasSizeOf(EditorDocument document) {
  final size = document.spec.size;
  return Size(size.width.toDouble(), size.height.toDouble());
}
