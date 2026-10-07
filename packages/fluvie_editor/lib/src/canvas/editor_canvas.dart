import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart'
    show LivePlaybackController, LivePlayer, PlacedOverrides, Placement, PreviewMediaScope, Video;
import 'package:fluvie/rendering.dart' show MediaResolver, WebClipDecoder;
import 'package:fluvie_editor/src/canvas/effect_warm_host.dart';
import 'package:fluvie_editor/src/canvas/slide_deriver.dart';
import 'package:fluvie_editor/src/colour/colour_scopes.dart';
import 'package:fluvie_editor/src/colour/scope_preview.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/selection/canvas_interaction.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';
import 'package:fluvie_editor/src/widgets/canvas_viewport.dart';
import 'package:obers_ui/obers_ui.dart' show OiBuildContextThemeExt;

part 'editor_canvas_state.dart';
part 'editor_canvas_stage.dart';

/// The editing stage: one slide of the document, rendered by the same
/// fluvie pipeline that presents and exports it, on a soft backdrop inside
/// a zoomable viewport — following the shared [transport] frame-exactly,
/// or held at its settled frame without one.
///
/// With [wholeDocument] the stage mounts the full composition instead (the
/// video mode's continuous preview): the transport's absolute frame decides
/// which scene is on stage, while [slide] keeps naming the scene the
/// interactive layer edits — the scene under the playhead, supplied by the
/// owner from the shared timebase.
final class EditorCanvas extends StatefulWidget {
  /// Shows [slide] of [document].
  const EditorCanvas({
    required this.document,
    required this.slide,
    this.viewportController,
    this.fitMargin = 48,
    this.interactive = false,
    this.wholeDocument = false,
    this.transport,
    this.settleFrame = 0,
    this.onCommand,
    this.onShowSlide,
    this.mediaResolver,
    this.clipDecoder,
    this.previewMaxEdge = 720,
    this.bypassEffects = false,
    this.onMediaReady,
    this.scopes,
    super.key,
  }) : assert(
         !wholeDocument || transport != null,
         'the whole-document stage needs the shared transport as its clock',
       );

  /// The deck being edited.
  final EditorDocument document;

  /// Optional read-only scopes of the rendered preview.
  final ColourScopesController? scopes;

  /// The scene index on stage.
  final int slide;

  /// The camera; pass one to drive zoom commands from outside. `null` and
  /// the canvas owns a camera itself.
  final CanvasViewportController? viewportController;

  /// Breathing room around the slide when it first fits the viewport.
  final double fitMargin;

  /// Whether the selection input layer mounts over the slide (Phase 2's
  /// editing surface; false keeps the canvas a pure viewer).
  final bool interactive;

  /// Whether the stage mounts the whole composition on the absolute clock
  /// (video mode) instead of the single derived [slide]. Requires a
  /// [transport].
  final bool wholeDocument;

  /// The slide's shared playhead: the stage mounts its clock, so a scrub
  /// or play shows exactly the transport's frame. The owner keeps the
  /// transport alive and swaps it per slide. Null holds the settled still
  /// on a canvas-owned clock (the pure-viewer case).
  final SlideTransport? transport;

  /// In [wholeDocument] mode, the [slide]'s settled frame on the absolute
  /// clock — past its incoming transition's blend and its entrances. Below
  /// it the scene is still displaced, so the interactive layer stays inert
  /// (the owner supplies it from the shared timebase). Unused otherwise.
  final int settleFrame;

  /// Receives the commands the canvas's tools produce (the owner dispatches
  /// them into its `DocumentHistory`). Null makes the canvas look-only.
  final void Function(EditorCommand command)? onCommand;

  /// Asks the host to put a slide on stage — the registry's slide commands
  /// (duplicate, delete, and friends) follow their result through it. Null
  /// leaves the stage where it is.
  final void Function(int slide)? onShowSlide;

  /// Optional injected decoder/resolver seams for hosted previews and tests.
  final MediaResolver? mediaResolver;

  /// The browser clip decoder; desktop uses the native resolver.
  final WebClipDecoder? clipDecoder;

  /// Longest decoded side for editing; delivery never reads this setting.
  final int? previewMaxEdge;

  /// Preview-only effect bypass. The authored document and export are untouched.
  final bool bypassEffects;

  /// Publishes ready preview media for timeline filmstrips.
  final ValueChanged<MediaResolver>? onMediaReady;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}
