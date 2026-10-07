part of 'video_render_request.dart';

extension _RequestValidation on VideoRenderRequest {
  void _validateCapabilities(RenderCapabilities capabilities) {
    final output = export ?? const Export.mp4();
    void require(String choice, {required bool supported}) {
      if (!supported) {
        throw FluvieCapabilityException(
          capability: choice,
          host: capabilities.backend,
          remedy: 'Choose a supported output or use a renderer advertising that capability.',
        );
      }
    }

    output.validate();
    require('${output.mode.name} export', supported: capabilities.supportsExport(output.mode.name));
    require('Audio mixing', supported: !audio || capabilities.audio);
    if (output.mode != ExportMode.mp4) return;
    require(
      '${output.codec.name} encoding',
      supported: capabilities.videoCodecs.contains(output.codec.name),
    );
    require(
      output.pixelFormat.name,
      supported: capabilities.pixelFormats.contains(output.pixelFormat.name),
    );
    require('Explicit CRF', supported: output.crf == null || capabilities.crf);
    require('Target bitrate', supported: output.bitRate == null || capabilities.targetBitRate);
    require(
      'Software encoder preset',
      supported: output.preset == EncoderPreset.medium || capabilities.presets,
    );
  }
}
