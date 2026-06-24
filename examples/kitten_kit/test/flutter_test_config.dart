import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';

/// Shared test bootstrap: golden tests run through Alchemist. Platform goldens
/// (real fonts) are byte-stable only Linux-to-Linux, so they are enabled on
/// Linux alone, the baseline platform for this repo.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: Platform.isLinux),
    ),
    run: () async => testMain(),
  );
}
