import 'package:flutter/services.dart';
import 'package:fluvie_mobile_encoder/src/fluvie_mobile_encoder_exception.dart';
import 'package:fluvie_mobile_encoder/src/mobile_encode_request.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_encoder.dart';

/// The real [MobileVideoEncoder]: invokes the platform encoder over a
/// [MethodChannel].
///
/// On Android the channel is served by `MediaCodec` + `MediaMuxer`; on iOS by
/// `AVAssetWriter` over VideoToolbox. A platform failure is rethrown as a
/// [FluvieMobileEncoderException], and a platform with no native encoder (a
/// desktop or the web) surfaces the same typed error rather than a raw
/// `MissingPluginException`.
final class MethodChannelMobileVideoEncoder implements MobileVideoEncoder {
  /// Creates an encoder over an optional [MethodChannel] (defaults to the
  /// package channel; tests pass a mock-backed channel).
  const MethodChannelMobileVideoEncoder([this._channel = _defaultChannel]);

  /// The platform channel name both native plugins register.
  static const String channelName = 'dev.fluvie/mobile_encoder';

  /// The method the platform side handles to run one encode.
  static const String encodeMethod = 'encode';

  static const MethodChannel _defaultChannel = MethodChannel(channelName);

  final MethodChannel _channel;

  @override
  Future<void> encode(MobileEncodeRequest request) async {
    try {
      await _channel.invokeMethod<void>(encodeMethod, request.toArguments());
    } on PlatformException catch (error) {
      throw FluvieMobileEncoderException(
        error.message ?? 'The platform encoder failed.',
        code: error.code,
      );
    } on MissingPluginException {
      throw const FluvieMobileEncoderException(
        'No on-device encoder is registered for this platform. '
        'fluvie_mobile_encoder supports Android and iOS only.',
        code: 'unsupported_platform',
      );
    }
  }
}
