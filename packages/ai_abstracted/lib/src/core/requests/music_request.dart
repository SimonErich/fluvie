import 'package:ai_abstracted/src/core/generation_request.dart';
import 'package:ai_abstracted/src/core/media_kind.dart';
import 'package:meta/meta.dart';

/// A request to generate a musical track.
@immutable
final class MusicRequest extends GenerationRequest {
  /// Creates a [MusicRequest].
  const MusicRequest({
    required super.prompt,
    super.seed,
    super.model,
    this.seconds,
    this.instrumental = false,
    this.title,
    this.style,
    this.format = 'mp3',
    this.extra = const {},
  });

  /// The desired track length in seconds, when the provider supports it.
  final double? seconds;

  /// Whether to generate an instrumental track with no vocals (defaults false).
  final bool instrumental;

  /// An optional track title, for providers that accept one.
  final String? title;

  /// An optional musical style or genre hint.
  final String? style;

  /// The desired audio container format (defaults to `mp3`).
  final String format;

  /// Any extra provider-specific fields, passed through verbatim.
  final Map<String, Object?> extra;

  @override
  MediaKind get kind => MediaKind.music;
}
