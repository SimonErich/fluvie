part of 'audio_workspace_panel.dart';

extension _AudioWorkspaceMeter on _AudioWorkspacePanelState {
  Widget _meter(String name, AudioMeterLevel level) {
    String db(double v) => v <= 0 ? '−∞' : gainToDecibels(v).toStringAsFixed(1);
    return Semantics(
      label: '$name peak ${db(level.peak)} decibels, RMS ${db(level.rms)} decibels',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OiLabel.small(
              'Peak ${db(level.peak)} dB  ·  RMS ${db(level.rms)} dB${level.clipping ? '  ·  CLIP' : ''}',
            ),
            SizedBox(
              height: 5,
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * level.peak.clamp(0, 1),
                    color: level.clipping ? context.colors.error.base : context.colors.primary.base,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
