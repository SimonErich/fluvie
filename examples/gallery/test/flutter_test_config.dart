import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';

/// Shared test bootstrap: golden tests run through Alchemist.
///
/// CI goldens (Ahem-font, geometry-only) are generated and compared on every
/// machine. Platform goldens (real fonts) are byte-stable only Linux-to-Linux
/// with a pinned Flutter, so they are enabled on Linux alone, the baseline
/// platform for this repo (mirrors `packages/fluvie/test/flutter_test_config.dart`).
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(
        enabled: Platform.isLinux,
      ),
    ),
    run: () async => testMain(),
  );
}
