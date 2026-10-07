/// Edit a Fluvie presentation visually: a direct-manipulation canvas, an
/// inspector, and a timeline over the same `.fluvie` document the renderer
/// plays and the presenter presents.
///
/// The editor edits the spec itself through an immutable `EditorDocument`
/// wrapper — saving is identity, and everything it can author is already
/// serializable.
library;

export 'src/api/canvas_api.dart';
export 'src/api/commands_api.dart';
export 'src/api/document_api.dart';
export 'src/api/media_api.dart';
export 'src/api/timeline_api.dart';
export 'src/api/widgets_api.dart';
export 'src/api/workspace_api.dart';
