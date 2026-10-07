import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// The top bar's Export dropdown: `.fluvie` (Save as under an export
/// label), the printed Dart source, one PNG per slide, one PDF page per
/// slide, and — where the platform can render — an MP4 through fluvie's
/// pipeline.
///
/// A null [onExportVideo] means this platform cannot render right now; the
/// entry stays visible but disabled and carries the render service's own
/// [videoUnavailableNote] — honest, not hidden.
final class ExportMenu extends StatelessWidget {
  /// Creates the menu.
  const ExportMenu({
    required this.onExportFluvie,
    required this.onExportDart,
    required this.onExportImages,
    required this.onExportPdf,
    required this.onExportVideo,
    this.videoUnavailableNote = 'needs the desktop app',
    super.key,
  });

  /// Saves the document to a freshly picked `.fluvie` target.
  final VoidCallback onExportFluvie;

  /// Writes the fluvie_cli printer's Dart source to a picked file.
  final VoidCallback onExportDart;

  /// Renders every slide's settled state to a PNG.
  final VoidCallback onExportImages;

  /// Renders every slide's settled state into one PDF, a page per slide.
  final VoidCallback onExportPdf;

  /// Renders the deck to an MP4, or null where the platform cannot.
  final VoidCallback? onExportVideo;

  /// Why the video entry is disabled when [onExportVideo] is null, straight
  /// from the render service (the desktop app on a plain web build, the
  /// ffmpeg.wasm bridge on a page missing it).
  final String videoUnavailableNote;

  @override
  Widget build(BuildContext context) {
    final video = onExportVideo;
    return OiContextMenu(
      label: 'Export menu',
      openOnTap: true,
      items: [
        OiMenuItem(label: 'Export .fluvie', onTap: onExportFluvie),
        OiMenuItem(label: 'Export Dart source', onTap: onExportDart),
        OiMenuItem(label: 'Export slide images (PNG)', onTap: onExportImages),
        OiMenuItem(label: 'Export PDF', onTap: onExportPdf),
        if (video == null)
          OiMenuItem(label: 'Export video ($videoUnavailableNote)', enabled: false)
        else
          OiMenuItem(label: 'Export video (MP4)', onTap: video),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OiLabel.body('Export'),
            SizedBox(width: 2),
            OiIcon.decorative(icon: OiIcons.chevronDown, size: 14),
          ],
        ),
      ),
    );
  }
}
