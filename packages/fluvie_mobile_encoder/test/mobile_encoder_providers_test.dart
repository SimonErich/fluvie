import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('mobileVideoEncoderProvider defaults to the method-channel encoder', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(mobileVideoEncoderProvider),
      isA<MethodChannelMobileVideoEncoder>(),
    );
  });

  test('onDeviceVideoRendererProvider builds a renderer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(onDeviceVideoRendererProvider), isA<OnDeviceVideoRenderer>());
  });

  test('the renderer provider honors an overridden encoder', () {
    final container = ProviderContainer(
      overrides: [mobileVideoEncoderProvider.overrideWithValue(FakeMobileVideoEncoder())],
    );
    addTearDown(container.dispose);
    expect(container.read(onDeviceVideoRendererProvider), isA<OnDeviceVideoRenderer>());
  });
}
