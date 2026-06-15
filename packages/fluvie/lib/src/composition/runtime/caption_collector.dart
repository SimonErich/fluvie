import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';

/// The [CaptionSource] [video] declares, or `null` when it has no caption
/// track.
///
/// A pure structural read over the constructor data, with no mounting and no
/// async: the render shell hands this to `MediaResolver.preResolveCaptions` so
/// the SRT/VTT file is read and parsed once before frame 0, exactly like media.
/// A Video carries at most one caption track, so this returns one source, not
/// a set.
CaptionSource? collectCaptionSource(Video video) => video.captions?.captionSource;
