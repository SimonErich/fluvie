/// Edit a Fluvie presentation visually: a direct-manipulation canvas, an
/// inspector, and a timeline over the same `.fluvie` document the renderer
/// plays and the presenter presents.
///
/// The editor edits the spec itself through an immutable `EditorDocument`
/// wrapper — saving is identity, and everything it can author is already
/// serializable.
library;

export 'src/canvas/editor_canvas.dart' show EditorCanvas;
export 'src/document/document_history.dart' show DocumentHistory;
export 'src/document/editor_command.dart'
    show
        AddSceneCommand,
        EditorCommand,
        InsertElementCommand,
        RemoveElementCommand,
        RemoveSceneCommand,
        ReorderElementCommand,
        ReorderSceneCommand,
        ReplaceElementCommand,
        SetElementMetaCommand,
        SetTransformCommand;
export 'src/document/editor_document.dart' show EditorDocument, EditorDocumentMutations;
export 'src/selection/scene_geometry.dart' show ElementGeometry, SceneGeometry;
export 'src/selection/selection_controller.dart' show SelectionController, selectionProvider;
export 'src/widgets/canvas_viewport.dart' show CanvasViewport, CanvasViewportController;
