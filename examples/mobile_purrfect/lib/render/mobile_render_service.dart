import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:kitten_kit/kitten_kit.dart';

/// Renders a kitten birthday card to an MP4 fully on the device.
///
/// A contract (not a typedef) so it is injected via Riverpod and faked in tests.
// ignore: one_member_abstracts
abstract interface class MobileRenderService {
  /// Renders the card for [catName] (with an optional [photoBytes] and a [song]),
  /// reporting 0..1 [onProgress], and returns the written MP4 file.
  Future<File> render({
    required String catName,
    required String song,
    Uint8List? photoBytes,
    void Function(double progress)? onProgress,
  });
}

/// The real service, backed by the native [OnDeviceVideoRenderer].
class OnDeviceMobileRenderService implements MobileRenderService {
  /// Creates the on-device render service.
  const OnDeviceMobileRenderService();

  @override
  Future<File> render({
    required String catName,
    required String song,
    Uint8List? photoBytes,
    void Function(double progress)? onProgress,
  }) {
    final photo = photoBytes == null
        ? null
        : Image.memory(
            photoBytes,
            frame: const PhotoFrame.polaroid(caption: 'My cat'),
          );
    return OnDeviceVideoRenderer().render(
      composition: birthdayCard(catName: catName, photo: photo, song: song),
      aspect: Aspect.square,
      // Matches KittenDurations.card (6 s).
      duration: const Duration(seconds: 6),
      longEdge: 480,
      audio: true,
      onProgress: (progress) {
        final total = progress.totalFrames;
        final done = progress.completedFrames;
        if (total != null && total > 0 && done != null) {
          onProgress?.call(done / total);
        }
      },
    );
  }
}

/// The injected render service (overridden with a fake in tests).
final Provider<MobileRenderService> mobileRenderServiceProvider = Provider<MobileRenderService>(
  (ref) => const OnDeviceMobileRenderService(),
);
