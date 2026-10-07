part of 'export_video_dialog.dart';

final class _ExportEncodingControls extends StatelessWidget {
  const _ExportEncodingControls(this.owner);

  final _ExportVideoFormState owner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OiSelect<ExportCodec>(
          label: 'Video codec',
          value: owner._options.codec,
          options: [
            for (final value in ExportCodec.values)
              OiSelectOption(
                value: value,
                label: value == ExportCodec.h264 ? 'H.264 (compatible)' : 'H.265 (HEVC)',
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              owner._refresh(() => owner._options = owner._options.copyWith(codec: value));
            }
          },
        ),
        const SizedBox(height: 8),
        OiSelect<String>(
          label: 'Rate control',
          value: owner._options.bitRate != null
              ? 'bitrate'
              : owner._options.crf != null
              ? 'crf'
              : 'quality',
          options: const [
            OiSelectOption(value: 'quality', label: 'Quality preset'),
            OiSelectOption(value: 'crf', label: 'Constant quality (CRF)'),
            OiSelectOption(value: 'bitrate', label: 'Target bitrate'),
          ],
          onChanged: (value) => owner._refresh(
            () => owner._options = switch (value) {
              'crf' => owner._options.copyWith(crf: 18),
              'bitrate' => owner._options.copyWith(bitRate: 8000000),
              _ => owner._options.copyWith(clearRateControl: true),
            },
          ),
        ),
        if (owner._options.crf != null)
          MathNumberInput(
            label: 'CRF (lower is higher quality)',
            value: owner._options.crf!.toDouble(),
            min: 0,
            max: 51,
            decimals: 0,
            onChanged: (value) =>
                owner._refresh(() => owner._options = owner._options.copyWith(crf: value.round())),
          ),
        if (owner._options.bitRate != null)
          MathNumberInput(
            label: 'Video bitrate Mbps',
            value: owner._options.bitRate! / 1000000,
            min: 0.1,
            max: 200,
            step: 0.5,
            onChanged: (value) => owner._refresh(
              () => owner._options = owner._options.copyWith(bitRate: (value * 1000000).round()),
            ),
          ),
      ],
    );
  }
}

final class _ExportCompatibilityControls extends StatelessWidget {
  const _ExportCompatibilityControls(this.owner);

  final _ExportVideoFormState owner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        OiSelect<EncoderPreset>(
          label: 'Encoder speed',
          value: owner._options.preset,
          options: [
            for (final value in EncoderPreset.values)
              OiSelectOption(value: value, label: value.name),
          ],
          onChanged: (value) {
            if (value != null) {
              owner._refresh(() => owner._options = owner._options.copyWith(preset: value));
            }
          },
        ),
        const SizedBox(height: 8),
        OiSelect<ExportPixelFormat>(
          label: 'Pixel format',
          value: owner._options.pixelFormat,
          options: [
            for (final value in ExportPixelFormat.values)
              OiSelectOption(value: value, label: value.name),
          ],
          onChanged: (value) {
            if (value != null) {
              owner._refresh(() => owner._options = owner._options.copyWith(pixelFormat: value));
            }
          },
        ),
        const SizedBox(height: 8),
        const OiLabel.small(
          'H.265 and 10-bit or 4:4:4 output require a compatible encoder and player.',
        ),
      ],
    );
  }
}
