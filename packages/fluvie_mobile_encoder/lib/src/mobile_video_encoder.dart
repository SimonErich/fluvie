import 'package:fluvie_mobile_encoder/src/mobile_encode_request.dart';

/// Encodes a captured RGBA frames file into an MP4 on the device.
///
/// Implementations never spawn a process or bundle a codec. The real one,
/// `MethodChannelMobileVideoEncoder`, calls the platform's hardware encoder over
/// a method channel; tests use `FakeMobileVideoEncoder`. A failure surfaces as a
/// `FluvieMobileEncoderException`.
// ignore: one_member_abstracts — platform seam (method channel behind it); mockable via provider.
abstract interface class MobileVideoEncoder {
  /// Encodes [request], writing the MP4 to `request.outputPath`.
  Future<void> encode(MobileEncodeRequest request);
}
