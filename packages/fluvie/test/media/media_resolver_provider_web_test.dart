import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/media/media_resolver_provider_web.dart';
import 'package:fluvie/src/media/web_image_media_resolver.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  test('the web provider resolves to a WebImageMediaResolver (images only)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mediaResolverProvider), isA<WebImageMediaResolver>());
  });
}
