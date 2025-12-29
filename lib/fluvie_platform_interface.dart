import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fluvie_method_channel.dart';

/// Platform interface for the Fluvie plugin.
///
/// This abstract class defines the interface that platform-specific
/// implementations must implement. Platform channels use this to provide
/// platform-specific functionality.
///
/// Platform implementations should extend this class and set themselves
/// as the [instance] when they register.
abstract class FluviePlatform extends PlatformInterface {
  /// Constructs a FluviePlatform.
  FluviePlatform() : super(token: _token);

  /// Verification token for ensuring platform implementations are valid.
  ///
  /// Used internally by [PlatformInterface.verifyToken] to prevent
  /// incorrect implementations from being registered.
  static final Object _token = Object();

  /// The current platform implementation instance.
  ///
  /// Defaults to [MethodChannelFluvie] but can be overridden by
  /// platform-specific implementations.
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
