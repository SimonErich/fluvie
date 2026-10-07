/// The Fluvie headless render CLI, as a library so it stays testable and so the
/// render server can reuse the capture→encode pipeline without a command line.
library;

export 'src/asset_catalog.dart';
export 'src/assets_command.dart';
export 'src/authored_artifacts.dart';
export 'src/authoring_benchmark.dart';
export 'src/benchmark_command.dart';
export 'src/bundle_command.dart';
export 'src/capture_process.dart' show isFluvieProject, resolveProjectDir;
export 'src/cli_failure.dart';
export 'src/cli_runner.dart';
export 'src/codegen/dart_spec_printer.dart' show printVideoSpecJson;
export 'src/dart_source_edit.dart';
export 'src/docs_command.dart';
export 'src/doctor_command.dart';
export 'src/edit_command.dart';
export 'src/export_flags.dart';
export 'src/ffmpeg/ffmpeg_cache.dart';
export 'src/ffmpeg/ffmpeg_downloader.dart';
export 'src/ffmpeg/ffmpeg_provisioner.dart';
export 'src/ffmpeg/ffmpeg_release.dart' show pinnedFfmpegBuildLabel, pinnedFfmpegVersion;
export 'src/ffmpeg_command.dart';
export 'src/ffmpeg_gate.dart' show FfmpegToolchain, ensureFfmpeg, ensureFfmpegToolchain;
export 'src/file_target.dart';
export 'src/frame_command.dart';
export 'src/generate_command.dart';
export 'src/init_command.dart';
export 'src/inspect_command.dart';
export 'src/native_render_worker.dart';
export 'src/output_verification.dart';
export 'src/preview_command.dart';
export 'src/process_runner.dart';
export 'src/project_assets.dart';
export 'src/render_command.dart';
export 'src/render_defines.dart';
export 'src/render_manifest.dart' show RenderManifest;
export 'src/render_pipeline.dart'
    show
        RenderPipelineOptions,
        ToolchainResolver,
        captureThenEncode,
        runRenderPipeline,
        validateExportFlags,
        validateFrames;
export 'src/render_progress.dart';
export 'src/render_worker_client.dart';
export 'src/review_command.dart';
export 'src/session_command.dart';
export 'src/stage_harness.dart';
export 'src/templates/file_harness_template.dart';
export 'src/validate_command.dart';
export 'src/video_project_bundle.dart';
export 'src/workspace_command.dart';
export 'src/workspace_server.dart';
export 'src/workspace_session.dart';
