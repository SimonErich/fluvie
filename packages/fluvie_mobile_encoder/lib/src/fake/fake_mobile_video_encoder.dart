import 'dart:io';

import 'package:fluvie_mobile_encoder/src/mobile_encode_request.dart';
import 'package:fluvie_mobile_encoder/src/mobile_video_encoder.dart';

/// An in-memory [MobileVideoEncoder] for tests.
///
/// Records every [MobileEncodeRequest] in [requests] and writes a one-byte
/// placeholder at `request.outputPath` so a caller that returns the output file
/// sees it exist. No platform channel and no real encoding. Set [throwOnEncode]
/// to simulate a device failure.
final class FakeMobileVideoEncoder implements MobileVideoEncoder {
  /// Creates a fake encoder. When [throwOnEncode] is non-null, [encode] throws
  /// it instead of writing the output.
  FakeMobileVideoEncoder({this.throwOnEncode});

  /// An exception to throw from [encode], or `null` to record and succeed.
  final Exception? throwOnEncode;

  /// Every request passed to [encode], in call order.
  final List<MobileEncodeRequest> requests = [];

  @override
  Future<void> encode(MobileEncodeRequest request) async {
    requests.add(request);
    final error = throwOnEncode;
    if (error != null) throw error;
    await File(request.outputPath).writeAsBytes(const [0]);
  }
}
