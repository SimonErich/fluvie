/// The Fluvie headless render CLI, as a library so it stays testable and so the
/// render server can reuse the capture→encode pipeline without a command line.
library;

export 'src/capture_process.dart' show resolveProjectDir;
export 'src/cli_failure.dart';
export 'src/cli_runner.dart';
export 'src/codegen/dart_spec_printer.dart' show printVideoSpecJson;
export 'src/edit_command.dart';
export 'src/export_flags.dart';
export 'src/ffmpeg/ffmpeg_cache.dart';
export 'src/ffmpeg/ffmpeg_provisioner.dart';
export 'src/ffmpeg/ffmpeg_release.dart' show pinnedFfmpegBuildLabel, pinnedFfmpegVersion;
export 'src/ffmpeg_command.dart';
export 'src/ffmpeg_gate.dart' show ensureFfmpeg;
export 'src/generate_command.dart';
export 'src/init_command.dart';
export 'src/init_prompt.dart' show InitPrompt, LineReader;
export 'src/process_runner.dart';
export 'src/render_command.dart';
export 'src/render_defines.dart';
export 'src/render_manifest.dart' show RenderManifest;
export 'src/render_pipeline.dart'
    show
        RenderPipelineOptions,
        captureThenEncode,
        runRenderPipeline,
        validateExportFlags,
        validateFrames;
export 'src/render_progress.dart';
