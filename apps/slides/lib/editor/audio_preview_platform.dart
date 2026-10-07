import 'package:slides/editor/audio_preview_platform_contract.dart';
import 'package:slides/editor/audio_preview_platform_io.dart'
    if (dart.library.js_interop) 'package:slides/editor/audio_preview_platform_web.dart'
    as platform;
export 'package:slides/editor/audio_preview_platform_contract.dart';

/// The native ffplay or browser Web Audio output backend.
AudioPreviewPlatform createAudioPreviewPlatform() => platform.createAudioPreviewPlatform();
