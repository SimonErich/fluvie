/// Runs each cleanup in [cleanups] in order, routing any thrown error to
/// [onError] and never re-throwing.
///
/// Used in a render's `finally` so a failure in the work being torn down (the
/// capture or encode) is never masked by a failure in the teardown itself; a
/// cleanup error is reported, not propagated.
Future<void> runGuarded(
  List<Future<void> Function()> cleanups,
  void Function(Object error, StackTrace stackTrace) onError,
) async {
  for (final cleanup in cleanups) {
    try {
      await cleanup();
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }
}
