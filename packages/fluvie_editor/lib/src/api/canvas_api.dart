/// Canvas interaction, selection, geometry, and placement API.
library;

export '../canvas/document_preview_host.dart' show DocumentPreviewHost, DocumentPreviewHostState;
export '../canvas/editor_canvas.dart' show EditorCanvas;
export '../canvas/slide_deriver.dart' show DerivedSlide, SlideDeriver;
export '../gizmo/transform_drag.dart' show GizmoTarget, TransformDrag;
export '../panels/layers_drop.dart'
    show LayerRowEntry, LayersDropPlan, LayersMoveIn, LayersMoveOut, LayersReorder, layersDropPlan;
export '../panels/layers_panel.dart' show LayersPanel;
export '../panels/slide_strip.dart' show SlideStrip;
export '../selection/entered_group.dart' show EnteredGroupController, enteredGroupProvider;
export '../selection/keyframe_selection.dart'
    show KeyframeSelectionController, SelectedKeyframe, keyframeSelectionProvider;
export '../selection/scene_geometry.dart' show ElementGeometry, SceneGeometry, groupFrameRect;
export '../selection/selection_controller.dart' show SelectionController, selectionProvider;
export '../snapping/guide_layer.dart' show GuideLayer;
export '../snapping/manual_guide.dart' show ManualGuide;
export '../snapping/snap_engine.dart' show SnapEngine, SnapResult;
export '../snapping/snap_guide_overlay.dart' show SnapGuideOverlay;
export '../snapping/snap_line.dart' show SnapKind, SnapLine, SnapOrientation;
export '../snapping/snap_preferences.dart'
    show SnapPreferences, SnapPreferencesController, snapPreferencesProvider;
export '../tools/asset_panel.dart' show AssetReusePanel;
export '../tools/element_placer.dart'
    show constrainedEnd, placeElementAt, placeElementIn, placeMediaIn;
export '../tools/media_importer.dart' show MediaImporter, MediaPick, mediaImporterProvider;
export '../tools/media_scan.dart' show usedMediaSources;
export '../tools/tool_controller.dart'
    show EditorTool, ShapeVariant, ToolController, ToolState, toolProvider;
