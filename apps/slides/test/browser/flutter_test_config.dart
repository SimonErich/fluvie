import 'dart:async';

/// Browser tests use the web test binding; native golden bootstrap imports IO.
Future<void> testExecutable(FutureOr<void> Function() testMain) async => testMain();
