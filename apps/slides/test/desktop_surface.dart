import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor targets desktop windows; the framework's 800x600 default is
/// narrower than the top bar's full control set. Editor-screen tests pump
/// on this desktop-sized surface instead.
void useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
