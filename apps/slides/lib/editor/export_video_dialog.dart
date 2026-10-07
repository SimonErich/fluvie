import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart'
    show EncoderPreset, ExportCodec, ExportPixelFormat, Quality, VideoSpec;
import 'package:fluvie_editor/fluvie_editor.dart' show MathNumberInput;
import 'package:obers_ui/obers_ui.dart';
import 'package:slides/editor/export_options.dart';

part 'export_video_basic_fields.part.dart';
part 'export_video_encoder_fields.part.dart';

/// What the export dialog resolved to: the options one render runs at, and
/// whether the deck's own frame rate should change first.
///
/// The `fps` field is separate from `options` because it is not an override at
/// all. A
/// deck's timeline is measured in its own frames, so changing the rate rewrites
/// the document (an undoable, digest-moving edit) before the render starts;
/// resolution and quality only steer one run.
typedef ExportChoice = ({ExportOptions options, int fps});

/// The resolution presets offered for a deck whose long edge is [deckLongEdge].
///
/// Always includes the deck's own edge, so "as authored" is one of the choices
/// and is what the dialog opens on. Larger presets are omitted: upscaling past
/// the authored canvas re-renders vector content sharper but cannot invent
/// detail in a clip, so offering it would promise more than it delivers.
///
/// Capped at four entries, largest first, because the control it feeds accepts
/// at most five segments and asserts rather than truncating.
List<int> exportLongEdgePresets(int deckLongEdge) {
  const ladder = [2160, 1440, 1080, 720, 480];
  final edges = <int>{deckLongEdge, ...ladder.where((edge) => edge < deckLongEdge)}.toList()
    ..sort((a, b) => b.compareTo(a));
  return edges.take(4).toList();
}

/// Opens the export dialog over [context] for [spec] and resolves to what the
/// author chose, or null when they dismissed it.
Future<ExportChoice?> showExportVideoDialog(
  BuildContext context, {
  required VideoSpec spec,
  bool advanced = false,
}) => OiDialogShell.show<ExportChoice>(
  context: context,
  semanticLabel: 'Export video',
  minWidth: 320,
  maxWidth: 520,
  builder: (close) => _ExportVideoForm(spec: spec, advanced: advanced, onDone: close),
);

/// The dialog body: resolution, frame rate and quality, opening on the deck's
/// own settings so the default action is "export what I authored".
final class _ExportVideoForm extends StatefulWidget {
  const _ExportVideoForm({required this.spec, required this.onDone, required this.advanced});

  final VideoSpec spec;
  final bool advanced;
  final void Function(ExportChoice choice) onDone;

  @override
  State<_ExportVideoForm> createState() => _ExportVideoFormState();
}

final class _ExportVideoFormState extends State<_ExportVideoForm> {
  late ExportOptions _options = ExportOptions.forSpec(widget.spec);
  late int _fps = widget.spec.fps;
  late bool _advanced = widget.advanced;

  int get _deckLongEdge => ExportOptions.forSpec(widget.spec).longEdge;

  /// The short edge the chosen long edge implies, so the label shows a real
  /// canvas rather than one number.
  String _sizeLabel(int longEdge) {
    final spec = widget.spec.size;
    final wide = spec.width >= spec.height;
    final short = (longEdge * (wide ? spec.height / spec.width : spec.width / spec.height)).round();
    return wide ? '$longEdge x $short' : '$short x $longEdge';
  }

  void _refresh(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OiDialog.form(
      label: 'Export video',
      title: 'Export video',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportBasicFields(this),
            const SizedBox(height: 12),
            OiButton.ghost(
              label: _advanced ? 'Hide encoder options' : 'Encoder options',
              onTap: () => setState(() => _advanced = !_advanced),
            ),
            if (_advanced) ...[_ExportEncodingControls(this), _ExportCompatibilityControls(this)],
            if (_fps != widget.spec.fps) ...[
              const SizedBox(height: 8),
              OiLabel.small(
                'Changing the frame rate changes the deck itself, because its '
                'timeline is measured in frames. It is undoable.',
                color: colors.textMuted,
              ),
            ],
          ],
        ),
      ),
      actions: [
        OiButton.primary(
          // Not just "Export": the menu that opened this dialog is also called
          // Export, and two controls with one name is a coin toss for anyone
          // driving by label, screen reader or test.
          label: 'Start export',
          onTap: () => widget.onDone((options: _options, fps: _fps)),
        ),
      ],
    );
  }

  void _quickPreset(String name) => setState(() {
    final edge = switch (name) {
      'Draft' => 720,
      'Share' => 1080,
      _ => _deckLongEdge,
    };
    _options = ExportOptions(
      longEdge: edge.clamp(1, _deckLongEdge),
      quality: switch (name) {
        'Draft' => Quality.low,
        'Share' => Quality.high,
        _ => Quality.max,
      },
      preset: name == 'Draft' ? EncoderPreset.ultrafast : EncoderPreset.medium,
    );
  });
}
