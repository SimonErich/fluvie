part of 'colour_panel.dart';

final class _ColourLooks extends StatelessWidget {
  const _ColourLooks({required this.onSelected});

  final ValueChanged<ColourLook>? onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final look in colourLooks)
        OiButton.ghost(
          key: ValueKey('look-${look.family}'),
          label: look.name,
          onTap: onSelected == null ? null : () => onSelected!(look),
        ),
    ],
  );
}

final class _GradeTransferActions extends StatelessWidget {
  const _GradeTransferActions({
    required this.onCopy,
    required this.onPaste,
    required this.onPasteToLane,
  });

  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onPasteToLane;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      OiButton.ghost(label: 'Copy grade', onTap: onCopy),
      OiButton.ghost(label: 'Paste grade', onTap: onPaste),
      OiButton.ghost(label: 'Paste to lane', onTap: onPasteToLane),
    ],
  );
}

final class _ColourCorrectionActions extends StatelessWidget {
  const _ColourCorrectionActions({
    required this.onCorrection,
    required this.onCurves,
    required this.importing,
    required this.onImport,
  });

  final VoidCallback onCorrection;
  final VoidCallback onCurves;
  final bool importing;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    children: [
      OiButton.ghost(label: 'Add correction', onTap: onCorrection),
      OiButton.ghost(label: 'Add curves', onTap: onCurves),
      OiButton.ghost(
        label: importing ? 'Importing LUT…' : 'Import .cube LUT',
        onTap: onImport,
      ),
    ],
  );
}
