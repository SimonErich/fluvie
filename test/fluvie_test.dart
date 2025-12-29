import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/fluvie_platform_interface.dart';
import 'package:fluvie/fluvie_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFluviePlatform
    with MockPlatformInterfaceMixin
    implements FluviePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FluviePlatform initialPlatform = FluviePlatform.instance;

  test('$MethodChannelFluvie is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFluvie>());
  });

  test('getPlatformVersion', () async {
    Fluvie fluviePlugin = Fluvie();
    MockFluviePlatform fakePlatform = MockFluviePlatform();
    FluviePlatform.instance = fakePlatform;

    expect(await fluviePlugin.getPlatformVersion(), '42');
  });
}
