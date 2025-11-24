import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

Future<void> iApplyAVintageeffectToAClip(WidgetTester tester) async {
  // We can't easily apply an effect to a widget in the test without a proper container.
  // We assume the RenderConfig will have it.
  // For now, we just pump a widget that represents the config source.
  // TODO: Implement proper effect application in widget tree
}
