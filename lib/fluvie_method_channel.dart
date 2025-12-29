import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fluvie_platform_interface.dart';

/// An implementation of [FluviePlatform] that uses method channels.
class MethodChannelFluvie extends FluviePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('fluvie');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
