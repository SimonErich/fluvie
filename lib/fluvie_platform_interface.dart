import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fluvie_method_channel.dart';

abstract class FluviePlatform extends PlatformInterface {
  /// Constructs a FluviePlatform.
  FluviePlatform() : super(token: _token);

  static final Object _token = Object();

  static FluviePlatform _instance = MethodChannelFluvie();

  /// The default instance of [FluviePlatform] to use.
  ///
  /// Defaults to [MethodChannelFluvie].
  static FluviePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FluviePlatform] when
  /// they register themselves.
  static set instance(FluviePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
