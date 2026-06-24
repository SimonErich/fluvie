import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/render/real_network_http_overrides.dart';

void main() {
  // Initializing the test binding installs flutter_test's global mock
  // HttpOverrides, which answers every request with HTTP 400 and never touches
  // the network. The override under test must escape that mock.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a real HttpClient inside the flutter_test mock binding', () {
    final mock = HttpClient();
    addTearDown(mock.close);

    final real = HttpOverrides.runWithHttpOverrides(HttpClient.new, RealNetworkHttpOverrides());
    addTearDown(real.close);

    expect(
      real.runtimeType,
      isNot(mock.runtimeType),
      reason: 'the zone-local override must beat the binding mock and build a real client',
    );
  });
}
