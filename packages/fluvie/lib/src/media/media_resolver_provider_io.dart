import 'package:fluvie/src/core/contracts/media_resolver.dart';
import 'package:fluvie/src/media/media_providers_common.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:riverpod/riverpod.dart';

export 'package:fluvie/src/media/media_providers_common.dart';

/// The media resolver used by the native render pipeline: a real
/// [MediaRepository] over the injected loader plus the clip probe/extraction
/// services. Overridable with a fake in tests; `NoMediaResolver` stays exported
/// as the deliberate media-less choice.
final mediaResolverProvider = Provider<MediaResolver>(
  (ref) => MediaRepository(
    loader: ref.watch(mediaBytesLoaderProvider),
    probeService: ref.watch(videoProbeServiceProvider),
    frameExtractor: ref.watch(frameExtractionServiceProvider),
  ),
);
